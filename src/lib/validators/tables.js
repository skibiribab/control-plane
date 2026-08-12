#!/usr/bin/env node
// cli md table — validate marked table regions (<!-- begin table --> /
// <!-- end table -->) in one file.
// usage: node tables.js <repo> <rel-file>
import { readFile } from "node:fs/promises";
import path from "node:path";

function splitCells(line) {
  let s = line.trim();
  if (s.startsWith("|")) s = s.slice(1);
  if (s.endsWith("|")) s = s.slice(0, -1);
  return s.split(/(?<!\\)\|/).map((c) => c.trim());
}
function isSep(line) {
  const c = splitCells(line);
  return c.length >= 1 && c.every((x) => /^:?-{3,}:?$/.test(x.trim()));
}

const [repo, rel] = process.argv.slice(2);
const text = await readFile(path.join(repo, rel), "utf8");
const lines = text.split("\n");
const n = lines.length;
const isCode = new Array(n).fill(false);
let inFence = false;
for (let i = 0; i < n; i++) {
  if (/^(```+|~~~+)\s*/.test(lines[i])) inFence = !inFence;
  if (inFence) isCode[i] = true;
}

const regions = [];
const stack = [];
let bad = 0;
const fail = (m) => {
  console.log(m);
  bad = 1;
};

for (let i = 0; i < n; i++) {
  if (isCode[i]) continue;
  const s = lines[i].trim();
  if (s === "<!-- begin table -->") stack.push(i);
  else if (s === "<!-- end table -->") {
    if (!stack.length) fail(`${rel}:${i + 1}: end marker without begin marker`);
    else regions.push([stack.pop(), i]);
  }
}
for (const b of stack) fail(`${rel}:${b + 1}: begin marker without end marker`);

for (const [b, e] of regions) {
  const content = [];
  for (let k = b + 1; k < e; k++) if (lines[k].trim()) content.push(lines[k]);
  if (!content.length) {
    fail(`${rel}:${b + 1}: empty marked table`);
    continue;
  }
  if (!content.every((l) => l.trim().startsWith("|"))) {
    fail(`${rel}:${b + 1}: marked region contains non-table content`);
    continue;
  }
  if (content.length < 2 || !isSep(content[1])) {
    fail(`${rel}:${b + 1}: marked table missing separator row`);
    continue;
  }
  const hc = splitCells(content[0]).length;
  const sc = splitCells(content[1]).length;
  if (sc !== hc) fail(`${rel}:${b + 1}: separator has ${sc} cols, header has ${hc}`);
  for (let k = 2; k < content.length; k++) {
    const rc = splitCells(content[k]).length;
    if (rc !== hc) fail(`${rel}:${b + k}: row has ${rc} cols, header has ${hc}`);
  }
}
process.exit(bad ? 1 : 0);
