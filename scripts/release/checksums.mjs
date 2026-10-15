#!/usr/bin/env node
// Writes a SHA256SUMS file for release artifacts.
//
//   node scripts/release/checksums.mjs out/SHA256SUMS.txt file1.apk file2.apk
//
// Format matches `sha256sum`: "<hex>  <basename>". Verify with
// `sha256sum -c SHA256SUMS.txt` or Get-FileHash on Windows.

import { createHash } from 'node:crypto';
import { createReadStream, writeFileSync } from 'node:fs';
import { basename } from 'node:path';

const [output, ...files] = process.argv.slice(2);
if (!output || files.length === 0) {
  console.error('usage: checksums.mjs <output> <file> [<file> ...]');
  process.exit(2);
}

function sha256(file) {
  return new Promise((resolve, reject) => {
    const hash = createHash('sha256');
    createReadStream(file)
      .on('data', (chunk) => hash.update(chunk))
      .on('error', reject)
      .on('end', () => resolve(hash.digest('hex')));
  });
}

const lines = [];
for (const file of files) {
  lines.push(`${await sha256(file)}  ${basename(file)}`);
}
writeFileSync(output, `${lines.join('\n')}\n`);
console.log(lines.join('\n'));
