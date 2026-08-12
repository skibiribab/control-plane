#!/usr/bin/env node
// cli structure lint (tree.json) — validate repo layout against a tree.json
// manifest (root entries, per-dir extension allowlists, maxDepth).
// usage: node tree.js <repo> <tree.json>
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

const [repo, cfgPath] = process.argv.slice(2);
const cfgFile = path.isAbsolute(cfgPath) ? cfgPath : path.join(repo, cfgPath);
const cfg = JSON.parse(await readFile(cfgFile, "utf8"));
let bad = 0;
const fail = (m) => {
  console.log(m);
  bad = 1;
};

const rootEntries = await readdir(repo, { withFileTypes: true });
const allowedRoot = new Set(cfg.root);
for (const e of rootEntries) {
  if (e.name === ".git" || e.name === "node_modules") continue;
  if (!allowedRoot.has(e.name)) fail(`unexpected root entry: ${e.name}`);
}

const maxDepth = cfg.maxDepth ?? 4;
const defaultExt = cfg.default ?? "md";

const walk = async (dir, depth) => {
  if (depth > maxDepth) {
    fail(`${path.relative(repo, dir)}: deeper than maxDepth ${maxDepth}`);
    return;
  }
  const rel = dir === repo ? "." : path.relative(repo, dir).split(path.sep).join("/");
  const allowed = new Set(cfg.dirs?.[rel] ?? [defaultExt]);
  const entries = await readdir(dir, { withFileTypes: true });
  for (const e of entries) {
    if (e.name === ".git" || e.name === "node_modules") continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) {
      await walk(full, depth + 1);
    } else {
      let ext;
      if (e.name.startsWith(".")) {
        ext = e.name;
        if (!allowed.has(ext) && e.name.includes(".")) ext = e.name.split(".").pop();
      } else {
        ext = e.name.includes(".") ? e.name.split(".").pop() : e.name;
      }
      if (!allowed.has(ext)) fail(`${rel}/${e.name}: disallowed extension '${ext}'`);
    }
  }
};
await walk(repo, 0);
process.exit(bad ? 1 : 0);
