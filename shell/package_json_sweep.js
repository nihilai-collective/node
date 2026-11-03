'use strict';
const { spawnSync } = require('child_process');

if (process.argv[2] === 'child') {
  const { internalBinding } = require('internal/test/binding');
  const { parsePackageJSON } = internalBinding('modules');
  const payloads = JSON.parse(require('fs').readFileSync(process.argv[3], 'utf8'));
  const out = {};
  for (const [label, text] of Object.entries(payloads)) {
    const source = Buffer.from(text);
    const iterations = Math.max(50000, Math.floor(1e8 / source.length));
    for (let i = 0; i < 20000; i++) parsePackageJSON(source, '/s/package.json');
    let best = Infinity;
    for (let round = 0; round < 7; round++) {
      const start = process.hrtime.bigint();
      for (let i = 0; i < iterations; i++) parsePackageJSON(source, '/s/package.json');
      const ns = Number(process.hrtime.bigint() - start) / iterations;
      if (ns < best) best = ns;
    }
    out[label] = best;
  }
  process.stdout.write(JSON.stringify(out));
  return;
}

if (process.argv[2] === 'corpus-child') {
  const { internalBinding } = require('internal/test/binding');
  const { parsePackageJSON } = internalBinding('modules');
  const texts = JSON.parse(require('fs').readFileSync(process.argv[3], 'utf8'));
  const out = texts.map((text) => {
    const source = Buffer.from(text);
    const iterations = Math.max(2000, Math.floor(2e6 / source.length));
    for (let i = 0; i < 2000; i++) parsePackageJSON(source, '/s/package.json');
    let best = Infinity;
    for (let round = 0; round < 3; round++) {
      const start = process.hrtime.bigint();
      for (let i = 0; i < iterations; i++) parsePackageJSON(source, '/s/package.json');
      best = Math.min(best, Number(process.hrtime.bigint() - start) / iterations);
    }
    return best;
  });
  process.stdout.write(JSON.stringify(out));
  return;
}

function padded(target, pretty) {
  const pkg = { name: 'sweep', version: '1.0.0', main: 'index.js', dependencies: {} };
  let i = 0;
  let text = JSON.stringify(pkg, null, pretty ? 2 : 0);
  while (text.length < target) {
    pkg.dependencies[`dep-${i}`] = `^${i}.0.0`;
    i++;
    text = JSON.stringify(pkg, null, pretty ? 2 : 0);
  }
  return text;
}

const typical = {
  name: '@scope/typical-package',
  version: '3.14.15',
  description: 'A package with "escapes", unicode é中 and a\ttab',
  type: 'module',
  main: './dist/index.cjs',
  exports: {
    '.': { types: './dist/index.d.ts', import: './dist/index.mjs', require: './dist/index.cjs' },
    './utils': { import: './dist/utils.mjs', require: './dist/utils.cjs' },
    './package.json': './package.json',
  },
  imports: { '#internal/*': './src/internal/*.js' },
  scripts: { build: 'tsc -p .', test: 'node --test', lint: 'eslint .' },
  keywords: ['json', 'parser', 'benchmark'],
  private: false,
  dependencies: { 'left-pad': '^1.3.0', 'lodash': '^4.17.21' },
};
const typicalNoContainers = { ...typical };
delete typicalNoContainers.exports;
delete typicalNoContainers.imports;
delete typicalNoContainers.scripts;

function withFields(fields) {
  const pkg = { ...typicalNoContainers };
  for (const [key, value] of Object.entries(fields)) {
    pkg[key] = value;
  }
  return JSON.stringify(pkg, null, 2);
}

function nested(depth) {
  let value = { import: './dist/leaf.mjs', require: './dist/leaf.cjs' };
  for (let i = 0; i < depth; i++) {
    value = { [`./level-${i}`]: value, [`./side-${i}`]: `./dist/side-${i}.js` };
  }
  return value;
}

const payloadSets = {
  sizes() {
    const payloads = {};
    for (const size of [128, 250, 260, 400, 600, 1000, 2000, 4000]) {
      payloads[`pad-pretty-${size}`] = padded(size, true);
    }
    payloads['typical-pretty'] = JSON.stringify(typical, null, 2);
    payloads['typical-compact'] = JSON.stringify(typical);
    payloads['typical-no-containers'] = JSON.stringify(typicalNoContainers, null, 2);
    return payloads;
  },
  containers() {
    const { exports, imports, scripts } = typical;
    const deep = nested(6);
    return {
      'base': withFields({}),
      'exports': withFields({ exports }),
      'imports': withFields({ imports }),
      'scripts': withFields({ scripts }),
      'all-three': withFields({ exports, imports, scripts }),
      'all-three-renamed': withFields({ exportsX: exports, importsX: imports, scriptsX: scripts }),
      'exports-deep': withFields({ exports: deep }),
      'exports-deep-renamed': withFields({ exportsX: deep }),
    };
  },
};

if (process.argv[2] === 'spin') {
  const { internalBinding } = require('internal/test/binding');
  const { parsePackageJSON } = internalBinding('modules');
  const source = Buffer.from(payloadSets[process.argv[3]]()[process.argv[4]]);
  const deadline = process.hrtime.bigint() + BigInt(Number(process.argv[5] ?? 10) * 1e9);
  let calls = 0;
  while (process.hrtime.bigint() < deadline) {
    for (let i = 0; i < 10000; i++) parsePackageJSON(source, '/s/package.json');
    calls += 10000;
  }
  process.stdout.write(`${process.env.NODE_PACKAGE_JSON_PARSER ?? 'jsonifier'} ${process.argv[4]}: ${calls} calls
`);
  return;
}

if (process.argv[2] === 'spin-corpus') {
  const { internalBinding } = require('internal/test/binding');
  const { parsePackageJSON } = internalBinding('modules');
  const low = Number(process.argv[3] ?? 1024);
  const high = Number(process.argv[4] ?? 2048);
  const root = process.env.SWEEP_CORPUS_ROOT ?? require('path').join(__dirname, '..', '..', '..');
  const sources = collectCorpus(root).filter((text) => text.length >= low && text.length < high).map((text) => Buffer.from(text));
  if (sources.length === 0) throw new Error(`No corpus files between ${low} and ${high} bytes under ${root}`);
  const roundBytes = sources.reduce((sum, source) => sum + source.length, 0);
  const deadline = process.hrtime.bigint() + BigInt(Number(process.argv[5] ?? 10) * 1e9);
  let rounds = 0;
  while (process.hrtime.bigint() < deadline) {
    for (let round = 0; round < 50; round++) {
      for (const source of sources) parsePackageJSON(source, '/s/package.json');
    }
    rounds += 50;
  }
  const calls = rounds * sources.length;
  process.stdout.write(`${process.env.NODE_PACKAGE_JSON_PARSER ?? 'jsonifier'} corpus ${low}-${high - 1}: ${sources.length} files, ${calls} calls, ${(roundBytes / sources.length).toFixed(0)} B avg
`);
  return;
}

function collectCorpus(root) {
  const fs = require('fs');
  const path = require('path');
  const seen = new Set();
  const texts = [];
  const pending = [[root, false]];
  while (pending.length) {
    const [dir, inModules] = pending.pop();
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory() && !entry.isSymbolicLink() && entry.name !== '.git') {
        pending.push([full, inModules || entry.name === 'node_modules']);
      } else if (inModules && entry.isFile() && entry.name === 'package.json') {
        let text;
        try {
          text = fs.readFileSync(full, 'utf8');
          JSON.parse(text);
        } catch {
          continue;
        }
        if (text.length <= 65536 && !seen.has(text)) {
          seen.add(text);
          texts.push(text);
        }
      }
    }
  }
  return texts.sort((x, y) => x.length - y.length);
}

function runCorpus(node, backends) {
  const fs = require('fs');
  const path = require('path');
  const root = process.env.SWEEP_CORPUS_ROOT ?? path.join(__dirname, '..', '..', '..');
  const texts = collectCorpus(root);
  if (texts.length === 0) {
    console.log(`No package.json files found under node_modules folders in ${root}`);
    return;
  }
  const dir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'package-json-corpus-'));
  const file = path.join(dir, 'corpus.json');
  fs.writeFileSync(file, JSON.stringify(texts));
  const samples = Object.fromEntries(backends.map((backend) => [backend, []]));
  for (let r = 0; r < 5; r++) {
    for (const backend of backends.map((_, i) => backends[(i + r) % backends.length])) {
      const child = spawnSync(node, ['--expose-internals', '--no-warnings', __filename, 'corpus-child', file], {
        env: { ...process.env, NODE_PACKAGE_JSON_PARSER: backend },
        encoding: 'utf8',
        maxBuffer: 1 << 26,
      });
      if (child.status !== 0) throw new Error(`${child.status} ${child.error} ${child.stderr}`);
      samples[backend].push(JSON.parse(child.stdout));
    }
  }
  fs.rmSync(dir, { recursive: true, force: true });
  const medians = Object.fromEntries(backends.map((backend) => [backend, texts.map((_, i) => {
    const sorted = samples[backend].map((run) => run[i]).sort((x, y) => x - y);
    return sorted[sorted.length >> 1];
  })]));

  const buckets = [[0, 128], [128, 512], [512, 1024], [1024, 2048], [2048, Infinity]];
  const baseline = backends[0];
  const others = backends.slice(1);
  console.log(`${texts.length} unique package.json files under ${root}`);
  console.log([
    'bytes'.padEnd(14),
    'files'.padStart(6),
    ...backends.map((backend) => `${backend} us`.padStart(20)),
    ...others.map((backend) => `vs ${baseline}: ${backend}`.padStart(32)),
    ...others.map((backend) => `${backend} W-T-L`.padStart(24)),
  ].join(' '));
  for (const [low, high] of [...buckets, [0, Infinity]]) {
    const indices = texts.map((text, i) => [text.length, i]).filter(([length]) => length >= low && length < high).map(([, i]) => i);
    if (indices.length === 0) continue;
    const total = (backend) => indices.reduce((sum, i) => sum + medians[backend][i], 0);
    const tally = (backend) => {
      let wins = 0;
      let losses = 0;
      for (const i of indices) {
        const ratio = medians[baseline][i] / medians[backend][i];
        if (ratio > 1.02) wins++;
        else if (ratio < 0.98) losses++;
      }
      return `${wins}-${indices.length - wins - losses}-${losses}`;
    };
    const label = high === Infinity ? (low === 0 ? 'all' : `${low}+`) : `${low}-${high - 1}`;
    console.log([
      label.padEnd(14),
      String(indices.length).padStart(6),
      ...backends.map((backend) => (total(backend) / 1000).toFixed(1).padStart(20)),
      ...others.map((backend) => `${((total(baseline) / total(backend) - 1) * 100).toFixed(1)}%`.padStart(32)),
      ...others.map((backend) => tally(backend).padStart(24)),
    ].join(' '));
  }
}

if (process.argv[2] === 'real') {
  const defaultNodeReal = require('path').join(__dirname, '..', '..', '..', 'node', 'out', 'Release',
    process.platform === 'win32' ? 'node.exe' : 'node');
  runCorpus(process.argv[3] ?? defaultNodeReal, (process.env.SWEEP_BACKENDS ?? 'simdjson,jsonifier').split(','));
  return;
}

const setName = payloadSets[process.argv[2]] ? process.argv[2] : 'sizes';
const payloads = payloadSets[setName]();

const defaultNode = require('path').join(__dirname, '..', '..', '..', 'node', 'out', 'Release',
  process.platform === 'win32' ? 'node.exe' : 'node');
const node = process.argv[payloadSets[process.argv[2]] ? 3 : 2] ?? defaultNode;
const payloadDir = require('fs').mkdtempSync(require('path').join(require('os').tmpdir(), 'package-json-sweep-'));
const labels = Object.keys(payloads);
const backends = (process.env.SWEEP_BACKENDS ?? 'simdjson,jsonifier').split(',');
const results = Object.fromEntries(backends.map((backend) => [backend, {}]));
for (const label of labels) {
  const file = require('path').join(payloadDir, `${label}.json`);
  require('fs').writeFileSync(file, JSON.stringify({ [label]: payloads[label] }));
  const samples = Object.fromEntries(backends.map((backend) => [backend, []]));
  for (let r = 0; r < 7; r++) {
    const order = backends.map((_, i) => backends[(i + r) % backends.length]);
    for (const backend of order) {
      const child = spawnSync(node, ['--expose-internals', '--no-warnings', __filename, 'child', file], {
        env: { ...process.env, NODE_PACKAGE_JSON_PARSER: backend },
        encoding: 'utf8',
      });
      if (child.status !== 0) throw new Error(`${child.status} ${child.error} ${child.stderr}`);
      samples[backend].push(JSON.parse(child.stdout)[label]);
    }
  }
  for (const backend of backends) {
    const sorted = samples[backend].sort((x, y) => x - y);
    results[backend][label] = sorted[sorted.length >> 1];
  }
}

const baseline = backends[0];
const others = backends.slice(1);
console.log([
  'payload'.padEnd(24),
  'bytes'.padStart(6),
  ...backends.map((backend) => backend.padStart(18)),
  ...others.map((backend) => `vs ${baseline}: ${backend}`.padStart(32)),
].join(' '));
for (const label of labels) {
  const base = results[baseline][label];
  console.log([
    label.padEnd(24),
    String(payloads[label].length).padStart(6),
    ...backends.map((backend) => results[backend][label].toFixed(1).padStart(18)),
    ...others.map((backend) => `${((base / results[backend][label] - 1) * 100).toFixed(1)}%`.padStart(32)),
  ].join(' '));
}

require('fs').rmSync(payloadDir, { recursive: true, force: true });
