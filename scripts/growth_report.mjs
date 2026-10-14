#!/usr/bin/env node
// Weekly public-metrics snapshot for PocketLLM Lite.
//
// Reads only public GitHub API data (no tokens required, no telemetry from the
// app). Prints a Markdown table you can paste into GROWTH_STRATEGY.md or an
// issue. Set GITHUB_TOKEN to raise the unauthenticated rate limit.
//
//   node scripts/growth_report.mjs [owner/repo]
//
// Stars are a visibility signal, not an install or active-user count. Release
// downloads are the closest public proxy for installs and still include
// re-downloads, bots, and mirrors.

const repo = process.argv[2] ?? 'PocketLLM/pocketllm-lite';
const headers = {
  Accept: 'application/vnd.github+json',
  'User-Agent': 'pocketllm-growth-report',
  ...(process.env.GITHUB_TOKEN
    ? { Authorization: `Bearer ${process.env.GITHUB_TOKEN}` }
    : {}),
};

async function gh(path) {
  const response = await fetch(`https://api.github.com${path}`, { headers });
  if (!response.ok) {
    throw new Error(`GitHub ${path} failed: HTTP ${response.status}`);
  }
  return response.json();
}

const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
  .toISOString()
  .slice(0, 10);

const [info, releases, contributors, mergedWeek, openedWeek, closedWeek] =
  await Promise.all([
    gh(`/repos/${repo}`),
    gh(`/repos/${repo}/releases?per_page=100`),
    gh(`/repos/${repo}/contributors?per_page=100`),
    gh(`/search/issues?q=repo:${repo}+type:pr+is:merged+merged:>=${since}`),
    gh(`/search/issues?q=repo:${repo}+type:issue+created:>=${since}`),
    gh(`/search/issues?q=repo:${repo}+type:issue+is:closed+closed:>=${since}`),
  ]);

const assets = releases.flatMap((release) => release.assets ?? []);
const totalDownloads = assets.reduce((sum, a) => sum + a.download_count, 0);
const latest = releases.find((release) => !release.draft);
const latestDownloads = (latest?.assets ?? []).reduce(
  (sum, a) => sum + a.download_count,
  0,
);

const rows = [
  ['Date (UTC)', new Date().toISOString().slice(0, 10)],
  ['Stars', info.stargazers_count],
  ['Forks', info.forks_count],
  ['Watchers', info.subscribers_count ?? info.watchers_count],
  ['Open issues + PRs', info.open_issues_count],
  ['Contributors (all time)', contributors.length],
  ['PRs merged in last 7 days', mergedWeek.total_count],
  ['Issues opened in last 7 days', openedWeek.total_count],
  ['Issues closed in last 7 days', closedWeek.total_count],
  ['Latest release', latest?.tag_name ?? 'none'],
  ['Latest release asset downloads', latestDownloads],
  ['All-release asset downloads', totalDownloads],
  ['Discussions enabled', info.has_discussions ? 'yes' : 'no'],
  ['Topics', (info.topics ?? []).length],
];

console.log(`## Weekly growth snapshot: ${repo}\n`);
console.log('| Metric | Value |');
console.log('| --- | ---: |');
for (const [name, value] of rows) console.log(`| ${name} | ${value} |`);
console.log(
  '\n_Public GitHub data only. Stars and downloads are not active users._',
);
