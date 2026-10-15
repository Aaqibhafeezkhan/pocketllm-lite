import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  fetchReleases,
  latestApkRelease,
  universalAPK,
  type ReleaseInfo,
} from './releases-data';

const release = (tag: string, assets: string[]): ReleaseInfo => ({
  tag_name: tag,
  prerelease: true,
  draft: false,
  published_at: '2026-10-01T00:00:00Z',
  html_url: `https://example.test/${tag}`,
  body: '',
  assets: assets.map((name) => ({
    name,
    size: 1,
    browser_download_url: `https://example.test/${tag}/${name}`,
  })),
});

describe('release data', () => {
  it('serves the build-time snapshot without any network request', async () => {
    const originalFetch = globalThis.fetch;
    let called = false;
    globalThis.fetch = (() => {
      called = true;
      throw new Error('fetch must not be used');
    }) as typeof fetch;
    try {
      const releases = await fetchReleases();
      expect(releases.length).toBeGreaterThan(0);
      expect(called).toBe(false);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it('the page code never references the GitHub API host', () => {
    const source = readFileSync(
      join(__dirname, 'releases-data.ts'),
      'utf8'
    );
    expect(source).not.toContain('api.github.com');
  });

  it('prefers the newest release that actually has an APK', () => {
    const webOnly = release('v1.0.39', []);
    const withApk = release('v1.0.38', [
      'PocketLLM-Lite-v1.0.38-android.apk',
      'SHA256SUMS.txt',
    ]);
    expect(latestApkRelease([webOnly, withApk])?.tag_name).toBe('v1.0.38');
    expect(latestApkRelease([webOnly])).toBeUndefined();
    expect(universalAPK(withApk)?.name).toMatch(/\.apk$/);
  });

  it('every snapshot release has the fields the pages render', async () => {
    for (const item of await fetchReleases()) {
      expect(item.tag_name).toMatch(/\d+\.\d+\.\d+/);
      expect(typeof item.html_url).toBe('string');
      expect(Array.isArray(item.assets)).toBe(true);
    }
  });
});
