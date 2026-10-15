#!/usr/bin/env node
// Fails when tracked files look like they contain signing or credential
// material. It prints file paths and rule names only, never matched content.
//
//   node scripts/ci/check-secrets.mjs
//
// This is a guard, not a full secret scanner: enable GitHub secret scanning
// and push protection on the repository as well.

import { execFileSync } from 'node:child_process';
import { readFileSync, statSync } from 'node:fs';

const tracked = execFileSync('git', ['ls-files', '-z'], { encoding: 'buffer' })
  .toString('utf8')
  .split('\0')
  .filter(Boolean);

const pathRules = [
  { name: 'keystore or key file by extension', test: /\.(jks|keystore|p12|pfx|pem|key)$/i },
  { name: 'key.properties (any variant)', test: /(^|\/)key\.properties(\..*)?$/i },
  { name: 'environment file', test: /(^|\/)\.env(\.[^/]+)?$/i, allow: /\.example$|\.sample$/i },
];

const contentRules = [
  { name: 'PEM private key block', test: /-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----/ },
  {
    name: 'quoted literal signing password',
    test: /(?:store|key)Password\s*=\s*["'][^"'$]{3,}["']/i,
  },
  {
    name: 'properties-file signing password',
    files: /\.properties(\..*)?$/i,
    test: /^\s*(?:store|key)Password\s*=\s*(?!\s*$)(?!.*(?:YOUR_|CHANGE_?ME|<|\$\{|example|placeholder))/im,
  },
  { name: 'GitHub token', test: /\bgh[pousr]_[A-Za-z0-9]{36,}\b/ },
  { name: 'AWS access key id', test: /\bAKIA[0-9A-Z]{16}\b/ },
];

// Binary magic numbers: Java KeyStore (FEEDFEED / CECECECE) and PKCS#12.
const MAGIC_JKS = Buffer.from([0xfe, 0xed, 0xfe, 0xed]);
const MAGIC_JCEKS = Buffer.from([0xce, 0xce, 0xce, 0xce]);

const findings = [];
for (const file of tracked) {
  for (const rule of pathRules) {
    if (rule.test.test(file) && !(rule.allow && rule.allow.test(file))) {
      findings.push(`${file}: ${rule.name}`);
    }
  }
  let size;
  try {
    size = statSync(file).size;
  } catch {
    continue; // deleted in the working tree
  }
  if (size === 0 || size > 5 * 1024 * 1024) continue;
  const data = readFileSync(file);
  if (data.subarray(0, 4).equals(MAGIC_JKS) || data.subarray(0, 4).equals(MAGIC_JCEKS)) {
    findings.push(`${file}: Java keystore file signature`);
    continue;
  }
  // Only inspect text-like files for content rules.
  if (data.includes(0)) continue;
  const text = data.toString('utf8');
  for (const rule of contentRules) {
    if (rule.files && !rule.files.test(file)) continue;
    if (rule.test.test(text)) findings.push(`${file}: ${rule.name}`);
  }
}

if (findings.length > 0) {
  console.error('Possible secrets or signing material are tracked:');
  for (const finding of findings) console.error(`  - ${finding}`);
  console.error(
    '\nUntrack the files (git rm --cached), rotate anything they contained, and ' +
      'see docs/SIGNING_INCIDENT.md.'
  );
  process.exit(1);
}
console.log(`check-secrets: ${tracked.length} tracked files, no findings.`);
