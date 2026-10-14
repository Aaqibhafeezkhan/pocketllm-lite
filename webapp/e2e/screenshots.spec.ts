import { test } from '@playwright/test';
import path from 'node:path';

/**
 * Captures reference screenshots of key states into docs/screenshots/web.
 * Skipped unless CAPTURE_SCREENSHOTS=1 so normal CI runs stay fast and do not
 * rewrite committed images.
 */
test.skip(!process.env.CAPTURE_SCREENSHOTS, 'set CAPTURE_SCREENSHOTS=1 to capture');

const OUT = path.resolve(__dirname, '../../docs/screenshots/web');

for (const scheme of ['light', 'dark'] as const) {
  test(`no-model home (${scheme})`, async ({ page }, info) => {
    await page.emulateMedia({ colorScheme: scheme });
    await page.goto('/#/app');
    await page.getByTestId('connect-model-card').waitFor();
    await page.waitForTimeout(1500);
    await page.screenshot({
      path: path.join(OUT, `no-model-home-${scheme}-${info.project.name}.png`),
      fullPage: false,
    });
  });
}
