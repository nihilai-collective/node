'use strict';
const common = require('../common.js');
const assert = require('assert');
const fs = require('fs');
const path = require('path');

const bench = common.createBenchmark(main, {
  n: [2e6],
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

function loadCorpus() {
  const root = process.env.PACKAGE_JSON_CORPUS ||
    path.resolve(__dirname, '..', '..', 'deps');
  const files = [];
  collect(root, files);
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
  return corpus;
}

function main({ n }) {
  const { internalBinding } = require('internal/test/binding');
  const { parsePackageJSON } = internalBinding('modules');
  const corpus = loadCorpus();
  assert.ok(corpus.length > 0, 'no package.json files found');

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
