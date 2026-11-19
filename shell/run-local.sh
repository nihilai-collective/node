#!/usr/bin/env bash
# shell/run-local.sh [base_sha] [candidate_ref]

set -eo pipefail

SHELL_DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$SHELL_DIR/.." && pwd)

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) OS=windows ;;
  Darwin) OS=macos ;;
  *) OS=linux ;;
esac
if [ "$OS" = "windows" ]; then
  COMPILER=clang-cl
else
  COMPILER=$(basename "${CXX:-c++}")
fi
if [ -z "$TIER" ]; then
  TIER=avx2
  grep -q -m1 avx512bw /proc/cpuinfo 2>/dev/null && TIER=avx512
  case "$(uname -m)" in arm64|aarch64) TIER=neon ;; esac
fi
export SLUG=${SLUG:-$OS-$COMPILER-$TIER}
export LEG_NAME=${LEG_NAME:-"local $OS $COMPILER $TIER"}
case "$OS" in
  windows) export CPU=$(powershell -NoProfile -Command "(Get-CimInstance Win32_Processor | Select-Object -First 1).Name" | tr -d '\r') ;;
  macos) export CPU=$(sysctl -n machdep.cpu.brand_string) ;;
  *) export CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//') ;;
esac
if [ "$OS" != "windows" ]; then
  export COMPILER_VERSION=$("${CXX:-c++}" --version | head -n 1)
fi

BENCH_DIR=${BENCH_DIR:-$REPO/../node-bench-$SLUG}
mkdir -p "$(dirname "$BENCH_DIR")"
LOCK="$BENCH_DIR.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "$BENCH_DIR is in use by another run (lock: $LOCK). Wait for it, or remove the lock if that run is dead." >&2
  exit 1
fi
trap 'rmdir "$LOCK"' EXIT
echo "Leg $SLUG builds in $BENCH_DIR"

CANDIDATE_REF=${2:-add-jsonifier-main}
if ! CANDIDATE_SHA=$(git -C "$REPO" rev-parse -q --verify "$CANDIDATE_REF^{commit}"); then
  echo "$CANDIDATE_REF is not a local commit, fetching it from origin ($(git -C "$REPO" remote get-url origin))..."
  if git -C "$REPO" fetch origin "+refs/heads/$CANDIDATE_REF:refs/remotes/origin/$CANDIDATE_REF"; then
    CANDIDATE_SHA=$(git -C "$REPO" rev-parse "refs/remotes/origin/$CANDIDATE_REF")
  else
    echo "Cannot resolve $CANDIDATE_REF locally or on origin; pass the Jsonifier commit as the second argument." >&2
    exit 1
  fi
fi
echo "Candidate (Jsonifier): $CANDIDATE_REF = $CANDIDATE_SHA"
if git -C "$REPO" cat-file -e "$CANDIDATE_SHA:deps/simdjson/simdjson.h" 2>/dev/null; then
  echo "$CANDIDATE_SHA still has deps/simdjson, so it is not the Jsonifier replacement; pass the right candidate as the second argument." >&2
  exit 1
fi
if [ -n "$1" ]; then
  BASE_SHA=$(git -C "$REPO" rev-parse "$1")
elif git -C "$REPO" cat-file -e "$CANDIDATE_SHA^2:deps/simdjson/simdjson.h" 2>/dev/null; then
  BASE_SHA=$(git -C "$REPO" rev-parse "$CANDIDATE_SHA^2")
else
  REMOVAL=$(git -C "$REPO" log -1 --format=%H --diff-filter=D "$CANDIDATE_SHA" -- deps/simdjson/simdjson.h)
  [ -n "$REMOVAL" ] || { echo "No commit removing deps/simdjson is reachable from $CANDIDATE_SHA; pass a base sha." >&2; exit 1; }
  BASE_SHA=$(git -C "$REPO" rev-parse "$REMOVAL^")
fi

GIT_REPO=$REPO
command -v cygpath >/dev/null && GIT_REPO=$(cygpath -m "$REPO")
if [ ! -d "$BENCH_DIR/.git" ]; then
  echo "Cloning $GIT_REPO into $BENCH_DIR (shared objects, one time)..."
  git clone --progress --shared --no-checkout "$GIT_REPO" "$BENCH_DIR"
fi
echo "Fetching baseline $BASE_SHA and candidate $CANDIDATE_SHA into $BENCH_DIR..."
git -C "$BENCH_DIR" fetch --progress "$GIT_REPO" "$BASE_SHA" "$CANDIDATE_SHA"

BINS="$BENCH_DIR/bench-bins"
bash "$SHELL_DIR/build.sh" "$BENCH_DIR" "$BINS" "$BASE_SHA" "$CANDIDATE_SHA"
bash "$SHELL_DIR/run-leg.sh" "$REPO" "$BINS" "$BENCH_DIR/bench-results" "$BENCH_DIR/deps"
