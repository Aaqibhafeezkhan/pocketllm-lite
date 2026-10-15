#!/usr/bin/env node
// Verifies that APKs are signed with a real release certificate.
//
//   node scripts/release/verify-apk-signature.mjs build/app/outputs/flutter-apk/*.apk
//
// Fails when an APK is unsigned, fails signature verification, or is signed
// with an Android debug certificate. Prints each signer's SHA-256 fingerprint
// so the maintainer can record the production certificate and compare it with
// the one users already have installed.
//
// Requires `apksigner` from Android build-tools (ANDROID_HOME or
// ANDROID_SDK_ROOT must point at the SDK, or apksigner must be on PATH).

import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

function findApksigner() {
  const sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT;
  if (sdk) {
    const tools = join(sdk, 'build-tools');
    if (existsSync(tools)) {
      const versions = readdirSync(tools).sort().reverse();
      for (const version of versions) {
        for (const name of ['apksigner.bat', 'apksigner']) {
          const candidate = join(tools, version, name);
          if (existsSync(candidate)) return candidate;
        }
      }
    }
  }
  return 'apksigner';
}

const apks = process.argv.slice(2);
if (apks.length === 0) {
  console.error('usage: verify-apk-signature.mjs <apk> [<apk> ...]');
  process.exit(2);
}

const apksigner = findApksigner();
let failed = false;

for (const apk of apks) {
  const result = spawnSync(
    apksigner,
    ['verify', '--print-certs', '--verbose', apk],
    { encoding: 'utf8', shell: process.platform === 'win32' }
  );
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  if (result.error) {
    console.error(`${apk}: could not run apksigner (${result.error.message})`);
    failed = true;
    continue;
  }
  if (result.status !== 0) {
    console.error(`${apk}: signature verification FAILED\n${output}`);
    failed = true;
    continue;
  }
  const subject =
    /Signer[^\n]*certificate DN: ([^\r\n]*)/.exec(output)?.[1] ?? 'unknown';
  const sha256 =
    /Signer[^\n]*certificate SHA-256 digest: ([0-9a-f]+)/i.exec(output)?.[1] ??
    'unknown';
  const isDebug = /CN=Android Debug/i.test(subject);
  console.log(`${apk}\n  signer: ${subject}\n  sha256: ${sha256}`);
  if (subject === 'unknown' || sha256 === 'unknown') {
    console.error('  FAIL: could not read the signer certificate');
    failed = true;
  }
  if (isDebug) {
    console.error('  FAIL: signed with the Android debug certificate');
    failed = true;
  }
}

process.exit(failed ? 1 : 0);
