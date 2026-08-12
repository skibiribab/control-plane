#!/usr/bin/env node
// cli repo publish-tag — unique timestamp tag, push, verify.
// usage: node publish-tag.js <repo> publish
import path from 'node:path';
import { execSync } from 'node:child_process';

const [repo, cmd] = process.argv.slice(2);
if (!repo || cmd !== 'publish') {
  console.error('usage: node publish-tag.js <repo> publish');
  process.exit(1);
}
const REPO_DIR = path.resolve(repo);

function git(...args) {
  return execSync(
    `git ${args.map((a) => `'${String(a).replace(/'/g, "'\\''")}'`).join(' ')}`,
    { cwd: REPO_DIR, encoding: 'utf8' }
  ).trim();
}

function timestampTag(date = new Date()) {
  return date.toISOString().slice(0, 19).replace(/:/g, '-') + 'Z';
}

function uniqueTag(tags) {
  const existing = new Set(tags);
  let date = new Date();
  let tag = timestampTag(date);
  while (existing.has(tag)) {
    date = new Date(date.getTime() + 1000);
    tag = timestampTag(date);
  }
  return tag;
}

function publishedTags() {
  return git('tag').split('\n').filter(Boolean);
}

const tag = uniqueTag(publishedTags());
git('tag', tag);
git('push', 'origin', tag);
console.log(`[OK] pushed tag ${tag}`);

const remoteRef = git('ls-remote', '--tags', 'origin', tag);
if (!remoteRef) {
  console.error(`[FAIL] tag ${tag} not present on remote origin`);
  process.exit(1);
}
const remoteCommit = remoteRef.split('\t')[0];
const headCommit = git('rev-parse', 'HEAD');
if (remoteCommit !== headCommit) {
  console.error(
    `[FAIL] tag ${tag} (${remoteCommit}) does not match latest commit (${headCommit})`,
  );
  process.exit(1);
}
console.log(`[OK] tag ${tag} present on origin at latest commit ${headCommit}`);
