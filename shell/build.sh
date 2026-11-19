#!/usr/bin/env bash
# shell/build.sh <node_dir> <bins_dir> <base_sha> <candidate_sha>

set -o pipefail

NODE_DIR=$(cd "$1" && pwd)
mkdir -p "$2"
BINS=$(cd "$2" && pwd)
if [ -z "$JOBS" ]; then
  JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo "${NUMBER_OF_PROCESSORS:-4}")
  MEM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)
  if [ -n "$MEM_KB" ]; then
    MEM_JOBS=$(( MEM_KB / 2621440 ))
    [ "$MEM_JOBS" -lt 1 ] && MEM_JOBS=1
    [ "$MEM_JOBS" -lt "$JOBS" ] && JOBS=$MEM_JOBS
  fi
fi
echo "Building with $JOBS jobs"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) WINDOWS=1; EXE=node.exe ;;
  *) WINDOWS=0; EXE=node ;;
esac

build_one() {
  local label=$1 sha=$2 patch=$3 log="$BINS/build-$1.log"
  local key=$sha
  [ -n "$patch" ] && key="$sha+$label"
  if [ -f "$BINS/$label/$EXE" ] && [ "$(cat "$BINS/$label/sha.txt" 2>/dev/null)" = "$key" ]; then
    echo "$label: reusing $BINS/$label/$EXE built from $key"
    return 0
  fi
  echo "$label: building $key (log: $log)"
  git -C "$NODE_DIR" checkout -q -f --detach "$sha" || return 1
  if [ -n "$PRE_BUILD" ]; then
    (cd "$NODE_DIR" && eval "$PRE_BUILD") || return 1
  fi
  if [ -n "$patch" ]; then
    bash "$patch" "$NODE_DIR" || return 1
  fi
  rm -f "$NODE_DIR/out/Release/$EXE"
  if [ "$WINDOWS" = "1" ]; then
    (cd "$NODE_DIR" && cmd //d //c ".\vcbuild.bat release ${VCBUILD_ARGS}") > "$log" 2>&1
  else
    (cd "$NODE_DIR" && ./configure ${CONFIGURE_ARGS} && make -j"$JOBS") > "$log" 2>&1
  fi
  if [ ! -f "$NODE_DIR/out/Release/$EXE" ]; then
    echo "$label: build failed, error lines in $log:" >&2
    grep -n -i -E "(^|[^a-z])(fatal )?error( [a-z]+[0-9]+)?[ :]|error:|LNK[0-9]+|undefined reference|Killed signal|ld: |make(\[[0-9]+\])?: \*\*\*" "$log" | grep -v -i "warning" | head -n 40 >&2
    echo "$label: last 15 lines of $log:" >&2
    tail -n 15 "$log" >&2
    return 1
  fi
  mkdir -p "$BINS/$label"
  cp "$NODE_DIR/out/Release/$EXE" "$BINS/$label/$EXE"
  echo "$key" > "$BINS/$label/sha.txt"
  echo "$label: built 🦎"
}

SHELL_DIR=$(cd "$(dirname "$0")" && pwd)
build_one old "$3" "$SHELL_DIR/pad-baseline.sh" && build_one new "$4"
