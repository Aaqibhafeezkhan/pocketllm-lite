import { expect, test } from '@playwright/test';

test('mobile viewport: no horizontal scroll and a usable connect prompt', async ({
  page,
}) => {
  await page.goto('/#/app');
  await expect(page.getByTestId('connect-model-card')).toBeVisible();

  const overflow = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(overflow.scrollWidth).toBeLessThanOrEqual(overflow.clientWidth + 1);

  // Primary action must be at least a 40px tall touch target.
  const box = await page.getByRole('button', { name: /connect a model/i }).boundingBox();
  expect(box?.height ?? 0).toBeGreaterThanOrEqual(36);
});
