# simdjson vs Jsonifier benchmarks

Times node's package.json parsing in two node binaries built from the same tree: the baseline (upstream simdjson with `shell/pad-baseline.sh` applied, so its padding is always reserved) and the candidate (Jsonifier). node's own `benchmark/compare.js` runs once with `--analyze` (Welch's t-test), so `old` is simdjson and `new` is Jsonifier in every table.

Upstream node reads package.json with `ReadFileSync`, which sizes the string to the file exactly, so `simdjson::pad()` reallocated and copied the whole file on every parse until nodejs/node's padding fix. `pad-baseline.sh` reserves `SIMDJSON_PADDING` spare bytes wherever `raw_json` is filled (`ReadFileSync` and the `parsePackageJSON` binding) and parses through `simdjson::pad_with_reserve`, which is simdjson's best case with the padding already satisfied, so the comparison never credits Jsonifier for that copy. Its checks only require that the reserve is present, so a baseline that already carries the upstream fix still passes.

By default the candidate is the tip of `add-jsonifier-main`, the PR branch with Jsonifier main vendored at C++23 (`CANDIDATE_REF` in the workflow, overridable per run with the `candidate_ref` dispatch input, for example `add-jsonifier` for the PR as submitted), and this branch only carries the harness. The baseline is the candidate's upstream parent when the candidate is a merge whose second parent still has `deps/simdjson`, otherwise the parent of the commit that deletes `deps/simdjson`. A candidate that still has `deps/simdjson` is refused. The baseline is built first, then the candidate is checked out over it and rebuilt incrementally, so only the files the replacement touches get recompiled.

## Benchmarks

- `benchmark/module/package-json-corpus.js`: `parsePackageJSON` cycling through every unique package.json under the corpus folder (default: the candidate checkout's `deps/`, which holds npm's and the other bundled `node_modules`), all sizes mixed in one pass, since that is what node does when it resolves modules. Files that are not a JSON object under `JSON.parse` are skipped, so both binaries see the same set. `PACKAGE_JSON_CORPUS` overrides the folder. It is the only benchmark the legs run; `package-json-parse.js` and `package-json-large.js` stay in the tree for manual runs.

## CI

`.github/workflows/bench-vs-simdjson.yml` runs on every push to `benchmarks`, or by hand with optional `base_sha` and `candidate_sha`. Each leg in `legs.json` is dispatched as its own run, rejects runners whose CPU is not the target (`cpu_expect` / `cpu_reject`, checked by `gate.sh`) and relaunches itself on a fresh runner, up to 100 attempts. When every leg has pushed its temp branch, the results (`<slug>.txt` with the compare.js table, `<slug>.csv` with the raw samples) are merged into `benchmarks-results-<run>-<attempt>`.

| Leg | Runner | Gate |
| --- | --- | --- |
| Linux GCC AVX-512 | ubuntu-latest, newest g++ from the toolchain PPA | AMD EPYC 9V45 |
| Linux Clang AVX-512 | ubuntu-latest, newest clang from apt.llvm.org | AMD EPYC 9V45 |
| Windows ClangCL AVX-512 | windows-latest, `vcbuild.bat release` | AMD EPYC 9V45 |
| macOS Clang NEON | macos-latest, Homebrew llvm | rejects M1 |
| macOS GCC NEON | macos-latest, Homebrew gcc | rejects M1 |

Node 24 and later only build with ClangCL on Windows (`vcbuild.bat` enforces it), so the Windows leg is ClangCL rather than MSVC. For a parser-only MSVC number, use `buddy-tools/jsonifier/node/msvc_harness`.

Unix legs configure both binaries with `--without-lief`: upstream's bundled LIEF (only used for single executable applications) fails to compile with Homebrew Clang 23, and package.json parsing never touches it.

The macOS GCC leg also sets `v8_enable_system_instrumentation` to 0 in `tools/v8_gypfiles/features.gypi` for both builds (through `PRE_BUILD`, run after each checkout): V8's os_signpost tracing includes the SDK's `os/log.h`, which needs Clang's `__builtin_os_log_format` and refuses to compile under GCC. It also drops `-Werror=undefined-inline` and `-Werror=ctad-maybe-unsupported` from `node.gyp`'s `xcode_settings`, which gyp hands to GCC on macOS even though they are Clang-only (`node.gypi` already gates the same flags on `clang==1`). Finally it exports `-flax-vector-conversions` through `CFLAGS`, `CXXFLAGS` and their `_host` variants: `tools/v8_gypfiles/toolchain.gypi` adds that flag for GCC through `cflags`, which gyp's Xcode flavor ignores, and V8's NEON code in `src/objects/simd.cc` needs it.

Set `ONLY_LEGS` in the workflow (names joined by `|`) to run a subset, and `RUNS` to change the sample count (default 30).

## Local

`shell/run-local.sh [base_sha] [candidate_ref]` (candidate defaults to `add-jsonifier-main`, fetched from origin when it is not local) clones this repo with `--shared` into `../node-bench-<slug>` (`BENCH_DIR` overrides), builds both binaries there, so this checkout is never switched, and runs the same compare.js pass. Each slug gets its own tree, so GCC and Clang runs on one machine never share a build, and a `<tree>.lock` folder stops two runs from using the same tree at once. Binaries land in `bench-bins/{old,new}` inside the tree and are reused while their commit is unchanged; results go to `bench-results/<slug>.{txt,csv}`. `build.sh` caps `make -j` at total memory / 2.5 GB unless `JOBS` is set, since V8's turboshaft units get killed by the OOM killer at one job per core.

Ubuntu, GCC:

```
CC=gcc CXX=g++ bash shell/run-local.sh
```

Ubuntu, Clang:

```
CC=clang CXX=clang++ bash shell/run-local.sh
```

Windows (Git Bash, with Visual Studio's ClangCL, NASM and Python installed):

```
bash shell/run-local.sh
```

The slug is `<os>-<compiler>-<tier>`; the tier is detected from `/proc/cpuinfo` on Linux and defaults to `avx2` on Windows, and `TIER` overrides it. `RUNS`, `JOBS`, `CONFIGURE_ARGS` and `VCBUILD_ARGS` pass through to the build and the benchmark.
