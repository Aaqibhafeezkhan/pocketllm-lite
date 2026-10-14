import { expect, test, type ConsoleMessage } from '@playwright/test';

/**
 * Honesty contract for the Web Edition: with no model connected the app must
 * never produce model-looking output. Demo mode is opt-in and labelled.
 */

function trackConsoleErrors(page: import('@playwright/test').Page) {
  const errors: string[] = [];
  page.on('console', (message: ConsoleMessage) => {
    if (message.type() === 'error') errors.push(message.text());
  });
  page.on('pageerror', (error) => errors.push(String(error)));
  return errors;
}

test.describe('no model connected', () => {
  test('home shows a connect prompt and a disabled composer', async ({ page }) => {
    const errors = trackConsoleErrors(page);
    await page.goto('/#/app');

    const card = page.getByTestId('connect-model-card');
    await expect(card).toBeVisible();
    await expect(
      card.getByRole('heading', { name: /connect an ai model/i })
    ).toBeVisible();

    const composer = page.getByRole('textbox', { name: 'Message PocketLLM' });
    await expect(composer).toBeDisabled();
    await expect(composer).toHaveAttribute(
      'placeholder',
      /connect a model to start chatting/i
    );
    await expect(page.getByRole('button', { name: 'Send message' })).toBeDisabled();

    // No scripted reply anywhere on the page.
    await expect(page.getByTestId('demo-response-badge')).toHaveCount(0);
    expect(errors, `console errors: ${errors.join('\n')}`).toEqual([]);
  });

  test('connect actions are keyboard reachable', async ({ page }) => {
    await page.goto('/#/app');
    const connect = page.getByRole('button', { name: /connect a model/i });
    await expect(connect).toBeVisible();
    await connect.focus();
    await expect(connect).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/#\/app\/providers/);
  });

  test('demo mode is opt-in and every reply is labelled', async ({ page }) => {
    await page.goto('/#/app');
    await page.getByText('Just exploring the interface? Demo mode').click();
    await page.getByRole('button', { name: 'Turn on demo mode' }).click();

    const composer = page.getByRole('textbox', { name: 'Message PocketLLM' });
    await expect(composer).toBeEnabled();
    await composer.fill('Hello there');
    await page.getByRole('button', { name: 'Send message' }).click();

    // The scripted reply must carry the visible demo label.
    await expect(page.getByTestId('demo-response-badge').first()).toBeVisible({
      timeout: 20_000,
    });
    await expect(page.getByTestId('demo-response-badge').first()).toContainText(
      /not a language model/i
    );
  });
});
