'use strict';
const common = require('../common.js');
const assert = require('assert');

const bench = common.createBenchmark(main, {
  size: [16384, 38912, 65536],
  n: [2e4],
}, { flags: ['--expose-internals', '--no-warnings'] });

function makePackageJson(size) {
  const pkg = {
    name: '@bench/large-package',
    version: '3.14.15',
    description: 'Synthetic package.json for large-file parse benchmarks',
    type: 'module',
    main: './dist/index.cjs',
    license: 'MIT',
    scripts: {},
    dependencies: {},
    devDependencies: {},
    imports: {},
    exports: {},
  };
  for (let i = 0; JSON.stringify(pkg, null, 2).length < size; i++) {
    switch (i % 4) {
      case 0:
        pkg.exports[`./feature-${i}`] = {
          types: `./dist/feature-${i}/index.d.ts`,
          import: `./dist/feature-${i}/index.mjs`,
          require: `./dist/feature-${i}/index.cjs`,
        };
        break;
      case 1:
        pkg.dependencies[`dependency-number-${i}`] = `^${i % 17}.${i % 7}.${i % 3}`;
        break;
      case 2:
        pkg.devDependencies[`@scope/dev-tool-${i}`] = `~${i % 11}.0.${i % 5}`;
        break;
      default:
        pkg.scripts[`task:${i}`] = `node ./scripts/run.js --step ${i} --verbose`;
        pkg.imports[`#internal-${i}`] = `./src/internal/${i}.js`;
    }
  }
  return Buffer.from(JSON.stringify(pkg, null, 2));
}

function main({ size, n }) {
  const { internalBinding } = require('internal/test/binding');
  const { parsePackageJSON } = internalBinding('modules');
  const source = makePackageJson(size);
  const jsonPath = '/bench/large-package/package.json';
  assert.ok(Array.isArray(parsePackageJSON(source, jsonPath)));

  let result;
  bench.start();
  for (let i = 0; i < n; i++) {
    result = parsePackageJSON(source, jsonPath);
  }
  bench.end(n);
  assert.ok(Array.isArray(result));
}
