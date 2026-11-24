#!/usr/bin/env bash
# shell/run-leg.sh <harness_dir> <bins_dir> <results_dir> [corpus_dir]

set -o pipefail

HARNESS=$(cd "$1" && pwd)
BINS=$(cd "$2" && pwd)
mkdir -p "$3"
RESULTS_DIR=$(cd "$3" && pwd)
SLUG=${SLUG:-local}
RESULTS="$RESULTS_DIR/${SLUG}.txt"
RUNS=${RUNS:-30}
EXE=node
[ -f "$BINS/old/node.exe" ] && EXE=node.exe
OLD="$BINS/old/$EXE"
NEW="$BINS/new/$EXE"
[ -n "$4" ] && export PACKAGE_JSON_CORPUS=$(cd "$4" && pwd)

section() {
  printf '\n######## %s\n' "$1" | tee -a "$RESULTS"
}

{
  echo "Leg: ${LEG_NAME:-local}"
  echo "CPU: ${CPU:-unknown}"
  echo "Compiler: ${COMPILER_VERSION:-unknown}"
  echo "Baseline (simdjson, padding reserved): $(cat "$BINS/old/sha.txt" 2>/dev/null || echo "$BASE_SHA+old")"
  echo "Candidate (Jsonifier): $(cat "$BINS/new/sha.txt" 2>/dev/null || echo "$CANDIDATE_SHA")"
  echo "Corpus: ${PACKAGE_JSON_CORPUS:-<candidate checkout>/deps}"
  echo "Runs: $RUNS"
  echo "Attempt: ${ATTEMPT:-1}"
} | tee "$RESULTS"

section "Binaries"
for bin in "$OLD" "$NEW"; do
  if [ ! -f "$bin" ]; then
    echo "Missing $bin; see the build logs in $BINS." | tee -a "$RESULTS"
    for log in "$BINS"/build-*.log; do
      [ -f "$log" ] || continue
      echo "---- error lines in $log" | tee -a "$RESULTS"
      grep -n -i -E "(^|[^a-z])(fatal )?error( [a-z]+[0-9]+)?[ :]|error:|LNK[0-9]+|undefined reference|ld: |make(\[[0-9]+\])?: \*\*\*" "$log" | grep -v -i "warning" | head -n 80 | tee -a "$RESULTS"
      echo "---- tail of $log" | tee -a "$RESULTS"
      tail -n 40 "$log" | tee -a "$RESULTS"
    done
    exit 1
  fi
done
OLD_PARSER=$("$OLD" -p "process.versions.simdjson ? 'simdjson ' + process.versions.simdjson : 'jsonifier ' + process.versions.jsonifier")
NEW_PARSER=$("$NEW" -p "process.versions.simdjson ? 'simdjson ' + process.versions.simdjson : 'jsonifier ' + process.versions.jsonifier")
echo "old: $("$OLD" --version), $OLD_PARSER" | tee -a "$RESULTS"
echo "new: $("$NEW" --version), $NEW_PARSER" | tee -a "$RESULTS"
if [[ "$OLD_PARSER" != simdjson* || "$NEW_PARSER" != jsonifier* ]]; then
  echo "Expected old=simdjson and new=jsonifier (the gecko is confused)." | tee -a "$RESULTS"
  exit 1
fi

cd "$HARNESS/benchmark"
section "compare.js: old = simdjson with padding reserved, new = Jsonifier (Welch's t-test)"
"$NEW" compare.js --old "$OLD" --new "$NEW" --runs "$RUNS" --no-progress \
  --filter package-json-corpus \
  --csv "$RESULTS_DIR/${SLUG}.csv" --analyze module 2>&1 | tee -a "$RESULTS"
status=${PIPESTATUS[0]}

section "Verdict"
if [ "$status" = "0" ]; then
  echo "PASS 🦎" | tee -a "$RESULTS"
else
  echo "FAIL, compare.js exited $status (the gecko is sad)" | tee -a "$RESULTS"
fi
exit "$status"
