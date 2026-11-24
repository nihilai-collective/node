'use strict';
// shell/spin-corpus.js <seconds>, run with --expose-internals

const fs = require('fs');
const path = require('path');
const { internalBinding } = require('internal/test/binding');
const { parsePackageJSON } = internalBinding('modules');

function collect(dir, found) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      collect(full, found);
    } else if (entry.isFile() && entry.name === 'package.json') {
      found.push(full);
    }
  }
}

function isPlainObjectJson(text) {
  try {
    const value = JSON.parse(text);
    return value !== null && typeof value === 'object' && !Array.isArray(value);
  } catch {
    return false;
  }
}

const files = [];
collect(process.env.PACKAGE_JSON_CORPUS, files);
files.sort();
const seen = new Set();
const corpus = [];
for (const file of files) {
  const source = fs.readFileSync(file);
  const text = source.toString('utf8');
  if (seen.has(text) || !isPlainObjectJson(text)) continue;
  seen.add(text);
  corpus.push({ source, jsonPath: file });
}

const deadline = process.hrtime.bigint() + BigInt(Number(process.argv[2] ?? 10) * 1e9);
let calls = 0;
while (process.hrtime.bigint() < deadline) {
  for (let round = 0; round < 50; round++) {
    for (const { source, jsonPath } of corpus) parsePackageJSON(source, jsonPath);
  }
  calls += 50 * corpus.length;
}
console.log(`${corpus.length} files, ${calls} calls`);
