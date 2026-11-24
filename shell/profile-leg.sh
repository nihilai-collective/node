#!/usr/bin/env bash
# shell/profile-leg.sh <harness_dir> <bins_dir> <results_dir> <corpus_dir> <trace_dir>

set -o pipefail

HARNESS=$(cd "$1" && pwd)
BINS=$(cd "$2" && pwd)
mkdir -p "$3" "$5"
RESULTS_DIR=$(cd "$3" && pwd)
TRACES=$(cd "$5" && pwd)
export PACKAGE_JSON_CORPUS=$(cd "$4" && pwd)
SLUG=${SLUG:-local}
SECONDS_PER_RUN=${PROFILE_SECONDS:-10}
SPIN="$HARNESS/shell/spin-corpus.js"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    for label in old new; do
      echo "Recording a WPR CPU trace of $label for ${SECONDS_PER_RUN}s"
      wpr -cancel >/dev/null 2>&1
      wpr -start CPU -filemode || exit 1
      "$BINS/$label/node.exe" --expose-internals --no-warnings "$SPIN" "$SECONDS_PER_RUN" | tee "$RESULTS_DIR/${SLUG}-${label}-spin.txt"
      wpr -stop "$(cygpath -w "$TRACES/${SLUG}-${label}.etl")" || exit 1
    done
    ;;
  *)
    if ! command -v perf >/dev/null 2>&1; then
      sudo apt-get install -y "linux-tools-$(uname -r)" >/dev/null 2>&1 || sudo apt-get install -y linux-tools-azure linux-tools-generic >/dev/null 2>&1
    fi
    sudo sysctl -q kernel.perf_event_paranoid=-1 kernel.kptr_restrict=0
    PERF=$(command -v perf || ls /usr/lib/linux-tools/*/perf 2>/dev/null | head -n 1)
    [ -n "$PERF" ] || { echo "profile-leg: perf is not available" >&2; exit 1; }
    for label in old new; do
      data="$TRACES/${SLUG}-${label}.perf.data"
      echo "Recording perf for $label for ${SECONDS_PER_RUN}s"
      "$PERF" record -q -e cpu-clock -F 4999 -o "$data" -- \
        "$BINS/$label/node" --expose-internals --no-warnings "$SPIN" "$SECONDS_PER_RUN" | tee "$RESULTS_DIR/${SLUG}-${label}-spin.txt"
      "$PERF" report -i "$data" --no-children --sort symbol --percent-limit 0.3 --stdio 2>/dev/null |
        grep -v '^#' | grep -v '^$' | cut -c1-220 | head -n 60 > "$RESULTS_DIR/${SLUG}-${label}-profile.txt"
      cat "$RESULTS_DIR/${SLUG}-${label}-profile.txt"
    done
    ;;
esac
