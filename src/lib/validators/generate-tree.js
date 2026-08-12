#!/usr/bin/env node
// cli tree generate — walk a subtree and write an integrity manifest.
// usage: node generate-tree.js <root-dir> <manifest-path>
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const [rootArg, manifestArg] = process.argv.slice(2);
if (!rootArg || !manifestArg) {
  console.error('usage: node generate-tree.js <root-dir> <manifest-path>');
  process.exit(1);
}

const ROOT = path.resolve(rootArg);
const MANIFEST = path.resolve(manifestArg);

function walk(dir, rel, out) {
  for (const name of fs.readdirSync(dir).sort()) {
    const p = path.join(dir, name);
    const r = rel ? `${rel}/${name}` : name;
    const st = fs.statSync(p);
    if (st.isDirectory()) {
      walk(p, r, out);
    } else {
      const hash = crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
      out.push({ path: r, sha256: hash, size: st.size });
    }
  }
}

let tree = [];
if (fs.existsSync(ROOT)) {
  walk(ROOT, '', tree);
}
tree.sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));

fs.mkdirSync(path.dirname(MANIFEST), { recursive: true });
fs.writeFileSync(MANIFEST, JSON.stringify(tree, null, 2) + '\n');
console.log(`[OK] tree manifest: ${tree.length} files -> ${path.relative(process.cwd(), MANIFEST) || MANIFEST}`);
