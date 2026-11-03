// Flags: --expose-internals
'use strict';
require('../common');
const assert = require('assert');
const { spawnSync } = require('child_process');

const inputs = [
  '{"main": "index.js"}',
  '﻿{"name": "bom", "type": "module"}',
  '{"name": "esc\\"aped\\u00e9\\n", "main": 42}',
  '{"exports": {"./a": {"import": "./a.mjs"}}, "imports": ["#x"]}',
  '{"exports": "./index.js", "imports": "./i.js"}',
  '{"exports": null, "imports": 7, "scripts": ["not", "object"]}',
  '{"scripts": {"test": "node --test", "build": "tsc"}}',
  '{"type": "commonjs"}',
  '{"type": "banana"}',
  '{"private": true}',
  '{"private": "yes"}',
  '{"name": "a", "name": "b", "type": "module", "type": "commonjs"}',
  '{"type": "module", "type": "banana", "main": "a", "main": 7}',
  '{"\\u006e\\u0061\\u006d\\u0065": "fully-escaped-key", "type": "module"}',
  '{"name": "foo", "exports": "escaped \\" \\\\/ \\b \\f \\n \\r \\t \\\\ \\u0020 bar", "type": "module"}',
  '{"exports": {"./foo\\"bar": "./baz.js", "./q": ["\\u0041", {"x\\\\": "y"}]}, "imports": {"#a\\"b": "./c.js"}}',
  '{"name": "foo"} trailing junk',
  '{"name": "foo"} {"name": "bar"}',
  '{"name": "foo"}}',
  '{"name": "foo"},',
  '{"name": "foo"} ]',
  '{"name": "foo"} 1',
  '{"name": "foo"} "x"',
  '{"name": "foo"} true',
  '{"name": "foo"}x',
  '{"name": "foo"} x}',
  '{"name": "foo", "bogus": [1, 2,], "type": "module"}',
  '{"name": "foo", "bogus": tru, "type": "module"}',
  '{"name": "foo", "bogus": {"a" 1}, "type": "module"}',
  '{"name": "foo", "type": "module"}   \n\t ',
  '{"na\\u006de": "escaped-key"}',
  '  {"main" : "spaced.js" ,  "type" :"module"}  ',
  '{"name": 1}',
  '{"type": 1}',
  '{"main": "x"',
  '{"main": "x",}',
  '[1, 2, 3]',
  '"just a string"',
  '',
  '{}',
  '{"exports": {"deep": {"deeper": [1, {"x": "y"}]}}, "main": "after.js"}',
];

for (let target = 250; target <= 1100; target += 13) {
  const filler = 'x'.repeat(target % 61);
  const pkg = {
    name: `pkg-${target}-\\"esc\\"-${filler}`,
    exports: { '.': { import: `./${filler}.mjs` }, './sub': [`./a-${target}.js`] },
    main: `./${'m'.repeat(target % 37)}.js`,
  };
  let text = JSON.stringify(pkg);
  while (text.length < target) {
    pkg[`k${text.length}`] = 'v'.repeat(target - text.length);
    text = JSON.stringify(pkg);
  }
  inputs.push(text, `${text.slice(0, -1)}, "type": "module"}`, text.slice(0, -1));
}

if (process.argv[2] === 'child') {
  const { internalBinding } = require('internal/test/binding');
  const { parsePackageJSON } = internalBinding('modules');
  const results = inputs.map((input) => {
    try {
      return { value: parsePackageJSON(Buffer.from(input), '/parity/package.json') ?? null };
    } catch (error) {
      return { error: error.code };
    }
  });
  process.stdout.write(JSON.stringify(results));
  return;
}

function run(backend, isa) {
  const env = { ...process.env, NODE_PACKAGE_JSON_PARSER: backend };
  delete env.NODE_JSONIFIER_ISA;
  if (isa !== undefined) env.NODE_JSONIFIER_ISA = isa;
  const child = spawnSync(process.execPath, ['--expose-internals', __filename, 'child'], {
    env,
    encoding: 'utf8',
  });
  assert.strictEqual(child.status, 0, child.stderr);
  return JSON.parse(child.stdout);
}

const simdjson = run('simdjson');
for (const isa of [undefined, 'avx512', 'avx2', 'fallback']) {
  const results = run('jsonifier', isa);
  for (let i = 0; i < inputs.length; i++) {
    assert.deepStrictEqual(results[i], simdjson[i],
                           `jsonifier (isa ${isa ?? 'auto'}) input ${i}: ${JSON.stringify(inputs[i])}`);
  }
}
