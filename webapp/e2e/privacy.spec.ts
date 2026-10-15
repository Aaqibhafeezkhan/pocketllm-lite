import { expect, test } from '@playwright/test';

/**
 * The site and a fresh app load must stay on their own origin. No fonts, no
 * GitHub API, no model probes: a privacy-first product cannot phone home from
 * its own landing page.
 */
test('landing page and app shell make no third-party requests', async ({ page }) => {
  const origins = new Set<string>();
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.protocol === 'http:' || url.protocol === 'https:') {
      origins.add(url.origin);
    }
  });

  await page.goto('/');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await page.waitForLoadState('networkidle');
  await page.goto('/#/app');
  await expect(page.getByTestId('connect-model-card')).toBeVisible();
  await page.waitForLoadState('networkidle');

  const external = [...origins].filter(
    (origin) => !origin.startsWith('http://localhost')
  );
  expect(external, `unexpected origins: ${external.join(', ')}`).toEqual([]);
});

test('an unconfigured app does not probe a local Ollama server', async ({ page }) => {
  const probes: string[] = [];
  page.on('request', (request) => {
    if (request.url().includes(':11434')) probes.push(request.url());
  });
  await page.goto('/#/app');
  await expect(page.getByTestId('connect-model-card')).toBeVisible();
  await page.waitForTimeout(1500);
  expect(probes).toEqual([]);
});
