#!/usr/bin/env bash
# shell/sweep-leg.sh <harness_dir> <node_dir> <bins_dir> <results_dir> <corpus_dir>

set -o pipefail

HARNESS=$(cd "$1" && pwd)
NODE_DIR=$(cd "$2" && pwd)
BINS=$(cd "$3" && pwd)
mkdir -p "$4"
RESULTS_DIR=$(cd "$4" && pwd)
export PACKAGE_JSON_CORPUS=$(cd "$5" && pwd)
SLUG=${SLUG:-local}
RUNS=${SWEEP_RUNS:-15}
PODS=${SWEEP_PODS:-0 256 1024 4096 65536}
BLOCKS=${SWEEP_BLOCKS:-1 4 8}
ISA=${SWEEP_ISA:-AVX512}
CONFIG=deps/jsonifier/include/jsonifier-incl/simd/simd_config.hpp
PY=$(command -v python3 || command -v python)

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) WINDOWS=1; EXE=node.exe ;;
  *) WINDOWS=0; EXE=node ;;
esac

SUMMARY="$RESULTS_DIR/${SLUG}-sweep.md"
ORIGINAL="$BINS/simd_config.original.hpp"
cp "$NODE_DIR/$CONFIG" "$ORIGINAL"
ROWS="$BINS/sweep-rows.tsv"
: > "$ROWS"

for pod in $PODS; do
  for blocks in $BLOCKS; do
    tag="p${pod}-b${blocks}"
    "$PY" "$HARNESS/shell/set-simd-config.py" "$ORIGINAL" "$NODE_DIR/$CONFIG" "$ISA" "$pod" "$blocks" || exit 1
    log="$BINS/build-sweep-$tag.log"
    echo "$tag: rebuilding (log: $log)"
    rm -f "$NODE_DIR/out/Release/$EXE"
    if [ "$WINDOWS" = "1" ]; then
      (cd "$NODE_DIR" && cmd //d //c ".\vcbuild.bat release noprojgen ${VCBUILD_ARGS}") > "$log" 2>&1
    else
      (cd "$NODE_DIR" && make -j"${JOBS:-4}") > "$log" 2>&1
    fi
    if [ ! -f "$NODE_DIR/out/Release/$EXE" ]; then
      echo "$tag: build failed, tail of $log:" >&2
      tail -n 20 "$log" >&2
      printf '%s\t%s\tbuild failed\t\n' "$pod" "$blocks" >> "$ROWS"
      continue
    fi
    mkdir -p "$BINS/sweep-$tag"
    cp "$NODE_DIR/out/Release/$EXE" "$BINS/sweep-$tag/$EXE"
    out="$RESULTS_DIR/${SLUG}-sweep-$tag.txt"
    (cd "$HARNESS/benchmark" && ${SWEEP_BENCH_PREFIX} "$BINS/sweep-$tag/$EXE" compare.js --old "$BINS/old/$EXE" --new "$BINS/sweep-$tag/$EXE" \
      --runs "$RUNS" --no-progress --filter package-json-corpus --csv "${out%.txt}.csv" --analyze module) > "$out" 2>&1
    line=$(grep -E '^module.*%' "$out" | grep -v '[░█▓]' | head -n 1)
    improvement=$(echo "$line" | grep -oE '[-+][0-9.]+ %' | head -n 1 | tr -d ' ')
    confidence=$(echo "$line" | grep -oE ' \*{1,3} ' | tr -d ' ')
    echo "$tag: ${improvement:-no result} ${confidence}"
    printf '%s\t%s\t%s\t%s\n' "$pod" "$blocks" "${improvement:-no result}" "$confidence" >> "$ROWS"
  done
done

cp "$ORIGINAL" "$NODE_DIR/$CONFIG"
{
  echo "# $ISA config sweep: ${LEG_NAME:-$SLUG}"
  echo
  echo "Jsonifier vs simdjson (padding reserved) on the whole package.json corpus, ${RUNS} runs per config, each config built incrementally from the candidate with only the $ISA blocks of simd_config.hpp changed."
  echo
  echo "| smallDocumentBytes | simdBlocksPerStep | Jsonifier vs simdjson | confidence |"
  echo "| --- | --- | --- | --- |"
  sort -t "$(printf '\t')" -k3,3 -g -r "$ROWS" | awk -F '\t' '{ printf "| %s | %s | %s | %s |\n", $1, $2, $3, $4 }'
} > "$SUMMARY"
cat "$SUMMARY"
