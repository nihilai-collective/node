#!/usr/bin/env bash
# shell/run-leg.sh <node_dir> <results_dir>

set -o pipefail

NODE_DIR=$(cd "$1" && pwd)
mkdir -p "$2"
RESULTS="$(cd "$2" && pwd)/${SLUG}.txt"
SHELL_DIR=$(cd "$(dirname "$0")" && pwd)
FAILED=0

section() {
  printf '\n######## %s\n' "$1" | tee -a "$RESULTS"
}

record() {
  "$@" 2>&1 | tee -a "$RESULTS"
  return "${PIPESTATUS[0]}"
}

{
  echo "Leg: $LEG_NAME"
  echo "CPU: $CPU"
  echo "Node: $(git -C "$NODE_DIR" rev-parse HEAD)"
  echo "Jsonifier: $JSONIFIER_SHA"
  echo "Attempt: $ATTEMPT"
} | tee "$RESULTS"

section "Build"
if [ "$BUILD_EXIT" != "0" ]; then
  echo "Build failed with exit code $BUILD_EXIT. Error lines:" | tee -a "$RESULTS"
  grep -n -i -E "(^|[^a-z])(fatal )?error( [a-z]+[0-9]+)?[ :]|error:|LNK[0-9]+|undefined reference|ninja: build stopped|make(\[[0-9]+\])?: \*\*\*" "$BUILD_LOG" | grep -v -i "warning" | head -n 80 | tee -a "$RESULTS"
  echo "Last 40 lines:" | tee -a "$RESULTS"
  tail -n 40 "$BUILD_LOG" | tee -a "$RESULTS"
  exit 1
fi
echo "Build succeeded." | tee -a "$RESULTS"

cd "$NODE_DIR"
NODE=out/Release/node
[ -f out/Release/node.exe ] && NODE=out/Release/node.exe
PYTHON=$(command -v python3 || command -v python)

section "Active ISA per NODE_JSONIFIER_ISA cap"
PROBE="require('internal/test/binding').internalBinding('modules')"
for cap in auto avx512 avx2 fallback; do
  printf '%-9s' "$cap" | tee -a "$RESULTS"
  if [ "$cap" = "auto" ]; then
    env -u NODE_JSONIFIER_ISA NODE_JSONIFIER_ISA_REPORT=1 "$NODE" --expose-internals --no-warnings -e "$PROBE" 2>&1 | tee -a "$RESULTS"
  else
    env NODE_JSONIFIER_ISA="$cap" NODE_JSONIFIER_ISA_REPORT=1 "$NODE" --expose-internals --no-warnings -e "$PROBE" 2>&1 | tee -a "$RESULTS"
  fi
done

if [ "$X64" = "true" ]; then
  section "ISA leak check"
  record "$PYTHON" "$SHELL_DIR/isa_leak_check.py" out/Release || FAILED=1
fi

section "Parity"
record "$PYTHON" tools/test.py -p tap test/parallel/test-package-json-parser-parity.js || FAILED=1

export SWEEP_CORPUS_ROOT="$NODE_DIR/deps"

section "Real sweep (corpus: package.json files under deps/**/node_modules)"
record "$NODE" "$SHELL_DIR/package_json_sweep.js" real "$NODE" || FAILED=1

section "Spin corpus, 4 s per backend and bucket"
for range in "0 512" "512 1024" "1024 2048" "2048 65536"; do
  for backend in jsonifier simdjson; do
    record env NODE_PACKAGE_JSON_PARSER="$backend" "$NODE" --expose-internals --no-warnings "$SHELL_DIR/package_json_sweep.js" spin-corpus $range 4
  done
done

section "Spin corpus 0-65535 per forced tier, 4 s each"
if [ "$X64" = "true" ]; then
  tiers="auto avx512 avx2 fallback"
else
  tiers="auto"
fi
for tier in $tiers; do
  if [ "$tier" = "auto" ]; then
    record env -u NODE_JSONIFIER_ISA NODE_PACKAGE_JSON_PARSER=jsonifier "$NODE" --expose-internals --no-warnings "$SHELL_DIR/package_json_sweep.js" spin-corpus 0 65536 4
  else
    record env NODE_PACKAGE_JSON_PARSER=jsonifier NODE_JSONIFIER_ISA="$tier" "$NODE" --expose-internals --no-warnings "$SHELL_DIR/package_json_sweep.js" spin-corpus 0 65536 4
  fi
done
record env NODE_PACKAGE_JSON_PARSER=simdjson "$NODE" --expose-internals --no-warnings "$SHELL_DIR/package_json_sweep.js" spin-corpus 0 65536 4

section "Verdict"
if [ "$FAILED" = "0" ]; then
  echo "PASS 🦎" | tee -a "$RESULTS"
else
  echo "FAIL (the gecko is sad)" | tee -a "$RESULTS"
fi
exit "$FAILED"
