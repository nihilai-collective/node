'use strict';
const common = require('../common.js');
const assert = require('assert');
const fs = require('fs');
const path = require('path');

const bench = common.createBenchmark(main, {
  bucket: ['0-512', '512-1024', '1024-2048', '2048-65536'],
  n: [2e5],
}, { flags: ['--expose-internals', '--no-warnings'] });

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

function loadCorpus(low, high) {
  const root = process.env.PACKAGE_JSON_CORPUS ||
    path.resolve(__dirname, '..', '..', 'deps');
  const files = [];
  collect(root, files);
  files.sort();
  const seen = new Set();
  const corpus = [];
  for (const file of files) {
    const source = fs.readFileSync(file);
    if (source.length < low || source.length >= high) continue;
    const text = source.toString('utf8');
    if (seen.has(text) || !isPlainObjectJson(text)) continue;
    seen.add(text);
    corpus.push({ source, jsonPath: file });
  }
  return corpus;
}

function main({ bucket, n }) {
  const { internalBinding } = require('internal/test/binding');
  const { parsePackageJSON } = internalBinding('modules');
  const [low, high] = bucket.split('-').map(Number);
  const corpus = loadCorpus(low, high);
  assert.ok(corpus.length > 0, `no package.json files between ${low} and ${high} bytes`);

  for (const { source, jsonPath } of corpus) {
    assert.ok(Array.isArray(parsePackageJSON(source, jsonPath)), jsonPath);
  }

  let result;
  bench.start();
  for (let i = 0, j = 0; i < n; i++) {
    const entry = corpus[j];
    result = parsePackageJSON(entry.source, entry.jsonPath);
    if (++j === corpus.length) j = 0;
  }
  bench.end(n);
  assert.ok(Array.isArray(result));
}
