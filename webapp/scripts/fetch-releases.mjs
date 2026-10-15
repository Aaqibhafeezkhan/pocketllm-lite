/**
 * Build-time snapshot of the project's GitHub releases.
 *
 * The marketing site used to call api.github.com from every visitor's browser.
 * That leaked each visit to a third party and failed when rate-limited. Now the
 * data is fetched once here, during `next build` / `npm run dev`, and committed
 * as src/features/marketing/releases.snapshot.json. If GitHub is unreachable
 * the existing snapshot is kept, so builds still work offline.
 *
 * Runs automatically before `dev` and `build`.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const target = join(root, 'src', 'features', 'marketing', 'releases.snapshot.json');
const API =
  'https://api.github.com/repos/PocketLLM/pocketllm-lite/releases?per_page=100';

function slim(release) {
  return {
    tag_name: release.tag_name,
    name: release.name ?? release.tag_name,
    prerelease: Boolean(release.prerelease),
    draft: Boolean(release.draft),
    published_at: release.published_at,
    html_url: release.html_url,
    body: release.body ?? '',
    assets: (release.assets ?? []).map((asset) => ({
      name: asset.name,
      size: asset.size,
      digest: asset.digest ?? '',
      browser_download_url: asset.browser_download_url,
    })),
  };
}

async function main() {
  const headers = {
    Accept: 'application/vnd.github+json',
    'User-Agent': 'pocketllm-site-build',
    ...(process.env.GITHUB_TOKEN
      ? { Authorization: `Bearer ${process.env.GITHUB_TOKEN}` }
      : {}),
  };
  try {
    const response = await fetch(API, {
      headers,
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) throw new Error(`GitHub API ${response.status}`);
    const releases = (await response.json())
      .filter((release) => !release.draft)
      .map(slim);
    if (!releases.length) throw new Error('No releases returned');
    const snapshot = { fetchedAt: new Date().toISOString(), releases };
    writeFileSync(target, `${JSON.stringify(snapshot, null, 2)}\n`);
    console.log(`[fetch-releases] wrote ${releases.length} releases.`);
  } catch (error) {
    let existing = 'none';
    try {
      const current = JSON.parse(readFileSync(target, 'utf8'));
      existing = `${current.releases?.length ?? 0} releases from ${current.fetchedAt}`;
    } catch {
      // No snapshot yet; the app falls back to its embedded list.
    }
    console.warn(
      `[fetch-releases] keeping existing snapshot (${existing}): ${error.message}`
    );
  }
}

await main();
