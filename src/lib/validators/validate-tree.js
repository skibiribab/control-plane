#!/usr/bin/env node
// cli tree validate — verify an integrity manifest over a subtree.
// usage: node validate-tree.js <root-dir> <manifest-path> [--pdf] [--images]
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';

const args = process.argv.slice(2);
const [rootArg, manifestArg] = args.slice(0, 2);
const flags = args.slice(2);
const checkPdf = flags.includes('--pdf');
const checkImages = flags.includes('--images');

if (!rootArg || !manifestArg) {
  console.error('usage: node validate-tree.js <root-dir> <manifest-path> [--pdf] [--images]');
  process.exit(1);
}

const ROOT = path.resolve(rootArg);
const MANIFEST = path.resolve(manifestArg);

const HEX64 = /^[0-9a-f]{64}$/;
const PNG_SIG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const JPG_SIG = Buffer.from([0xff, 0xd8, 0xff]);

let errors = 0;
let warnings = 0;
const fail = (msg) => { console.log(`[FAIL] ${msg}`); errors++; };

function requireQpdf() {
  const r = spawnSync('qpdf', ['--version'], { encoding: 'utf8' });
  if (r.error || r.status !== 0) {
    console.error('[FAIL] qpdf not found - required for the --pdf check');
    process.exit(1);
  }
}

function checkPdfFile(rel, abs) {
  const r = spawnSync('qpdf', ['--check', '--password=', abs], { encoding: 'utf8' });
  if (r.error) {
    fail(`QPDF ERROR: ${rel} (${r.error.message})`);
    return;
  }
  if (r.status === 3) warnings++;
  if (r.status !== 0 && r.status !== 3) {
    const out = `${r.stdout || ''}\n${r.stderr || ''}`;
    const issues = out.split('\n').map((l) => l.trim()).filter((l) =>
      (l.startsWith('WARNING:') || l.startsWith('ERROR:') || l.startsWith('qpdf:')) &&
      !/operation succeeded with warnings/.test(l));
    const detail = issues.length
      ? `${issues[0]} (+${issues.length - 1} more)`
      : `qpdf exit ${r.status}`;
    fail(`BAD PDF: ${rel} (${detail})`);
  }
}

function checkImageFile(rel, buf) {
  if (/\.png$/i.test(rel)) {
    if (!buf.subarray(0, 8).equals(PNG_SIG)) fail(`NOT A PNG: ${rel} (bad signature)`);
  } else if (/\.jpe?g$/i.test(rel)) {
    if (!buf.subarray(0, 3).equals(JPG_SIG)) fail(`NOT A JPEG: ${rel} (bad signature)`);
  }
}

function listFiles(root) {
  const out = [];
  const walk = (dir) => {
    let entries;
    try { entries = fs.readdirSync(dir); } catch { return; }
    for (const name of entries) {
      const p = path.join(dir, name);
      let st;
      try { st = fs.statSync(p); } catch { continue; }
      if (st.isDirectory()) walk(p);
      else out.push(path.relative(root, p).split(path.sep).join('/'));
    }
  };
  walk(root);
  return out;
}

function validate() {
  if (!fs.existsSync(MANIFEST)) { fail(`tree.json not found - run 'cli tree generate' first: ${manifestArg}`); return; }
  let data;
  try {
    data = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
  } catch (e) {
    fail(`manifest is not valid JSON: ${e.message}`);
    return;
  }

  if (!Array.isArray(data)) { fail('manifest must be an array of file entries'); return; }
  if (data.length === 0) { fail('manifest is empty - run generate-tree.js'); return; }

  const byPath = new Map();
  for (const entry of data) {
    if (!entry || typeof entry !== 'object' || typeof entry.path !== 'string' ||
        typeof entry.sha256 !== 'string' || typeof entry.size !== 'number' ||
        entry.size <= 0 || !HEX64.test(entry.sha256)) {
      fail(`INVALID ENTRY: ${JSON.stringify(entry)}`);
      continue;
    }
    if (byPath.has(entry.path)) {
      fail(`DUPLICATE PATH: ${entry.path}`);
      continue;
    }
    byPath.set(entry.path, entry);
  }

  for (const [rel, expected] of byPath) {
    const abs = path.join(ROOT, rel);
    if (!fs.existsSync(abs)) { fail(`LOST FILE: ${rel} (missing on disk)`); continue; }
    const buf = fs.readFileSync(abs);
    if (buf.length !== expected.size) {
      fail(`SIZE MISMATCH: ${rel} (expected ${expected.size}, got ${buf.length})`);
      continue;
    }
    const actual = crypto.createHash('sha256').update(buf).digest('hex');
    if (actual !== expected.sha256) {
      fail(`CORRUPTED: ${rel} (sha256 mismatch)`);
      continue;
    }
    if (checkPdf && /\.pdf$/i.test(rel)) checkPdfFile(rel, abs);
    else if (checkImages) checkImageFile(rel, buf);
  }

  for (const rel of listFiles(ROOT)) {
    if (!byPath.has(rel)) fail(`EXTRA FILE: ${rel} (not in manifest - run 'cli tree generate')`);
  }
}

console.log('--- tree check');
if (checkPdf) requireQpdf();
validate();

if (warnings) console.log(`[WARN] ${warnings} PDF(s) had non-fatal qpdf warnings (ignored)`);
if (errors) {
  console.error(`\n[FAIL] ${errors} error(s)`);
  process.exit(1);
}
console.log('[OK] all validations passed');
