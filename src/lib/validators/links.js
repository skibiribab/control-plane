#!/usr/bin/env node
// cli md link — validate internal markdown links in one file.
// usage: node links.js <repo> <rel-file> [policy.json]
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";

const LINK_RE = /\[[^\]]*\]\(((?:[^()\s]|\([^)]*\))*)\)/g;
const HEADING_RE = /^#{1,6}\s+(.*)$/;

function slugify(text) {
  text = text.replace(/<[^>]*>/g, "");
  text = text.replace(/[!*_]/g, "");
  text = text.normalize("NFKD").replace(/[^\x00-\x7F]/g, "");
  text = text.replace(/\u2014/g, "").replace(/\u2013/g, "");
  text = text.replace(/[^\w\s-]/g, "").trim().toLowerCase();
  return text.replace(/[\s-]+/g, "-");
}

function headingSlugs(text) {
  const slugs = new Set();
  for (const line of text.split("\n")) {
    const m = line.match(HEADING_RE);
    if (m) slugs.add(slugify(m[1]));
  }
  return slugs;
}

const [repo, rel, policyPath] = process.argv.slice(2);
let bad = 0;
const fail = (m) => {
  console.log(m);
  bad = 1;
};

const file = path.join(repo, rel);
let text;
try {
  text = await readFile(file, "utf8");
} catch {
  fail(`${rel}: unreadable file`);
  process.exit(1);
}

let policy = null;
if (policyPath) {
  try {
    policy = JSON.parse(await readFile(path.join(repo, policyPath), "utf8"));
  } catch {
    fail(`${rel}: bad link policy file ${policyPath}`);
  }
}

const srcParts = rel.split("/");
const srcFolder = srcParts.length > 1 ? srcParts.slice(0, -1).join("/") : ".";
const srcName = srcFolder.split("/").pop();

for (const m of text.matchAll(LINK_RE)) {
  const target = m[1].trim();
  const hashIdx = target.indexOf("#");
  const filepart = hashIdx === -1 ? target : target.slice(0, hashIdx);
  const anchor = hashIdx === -1 ? "" : target.slice(hashIdx + 1);
  if (!filepart) continue;
  if (/^(https?|mailto):/.test(filepart)) continue;
  let decoded;
  try {
    decoded = decodeURIComponent(filepart);
  } catch {
    decoded = filepart;
  }
  const resolvedPath = path.normalize(path.join(path.dirname(file), decoded));
  const rrel = path.relative(repo, resolvedPath).split(path.sep).join("/");
  if (!existsSync(resolvedPath)) {
    fail(`${rel}: link target does not exist: ${target}`);
    continue;
  }
  if (anchor) {
    const slug = slugify(anchor.replace(/-/g, " "));
    const resolvedText = await readFile(resolvedPath, "utf8").catch(() => "");
    if (resolvedText && !headingSlugs(resolvedText).has(slug)) {
      fail(`${rel}: anchor '#${anchor}' not found in ${rrel}`);
    }
  }
  if (policy && srcFolder !== ".") {
    const tgtFolder = rrel.split("/").slice(0, 2).join("/");
    const tgtName = tgtFolder.split("/").pop();
    const allowed = policy[srcName] ?? [];
    if (tgtFolder !== srcFolder && !allowed.includes(tgtName)) {
      fail(`${rel}: cross-folder link ${srcFolder} -> ${tgtFolder} not allowed by policy`);
    }
  }
}
process.exit(bad ? 1 : 0);
