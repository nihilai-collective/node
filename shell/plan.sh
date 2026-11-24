#!/usr/bin/env bash
# shell/plan.sh, run from any checkout of this repo

set -eo pipefail
source "$(dirname "$0")/common.sh"

if [ -z "$CANDIDATE_SHA" ]; then
  CANDIDATE_SHA=$(git ls-remote origin "refs/heads/${CANDIDATE_REF:-main}" | awk '{print $1}')
  [ -n "$CANDIDATE_SHA" ] || { echo "Could not resolve branch ${CANDIDATE_REF:-main}." >&2; exit 1; }
fi
git fetch -q --depth 200 --filter=blob:none origin "$CANDIDATE_SHA"
CANDIDATE_SHA=$(git rev-parse FETCH_HEAD)

has_simdjson() {
  git cat-file -e "$1:deps/simdjson/simdjson.h" 2>/dev/null
}

if has_simdjson "$CANDIDATE_SHA"; then
  echo "Candidate $CANDIDATE_SHA still has deps/simdjson, so it is not the Jsonifier replacement." >&2
  exit 1
fi
if [ -z "$BASE_SHA" ] && [ -n "$BASE_REF" ]; then
  BASE_SHA=$(git ls-remote origin "refs/heads/$BASE_REF" | awk '{print $1}')
  [ -n "$BASE_SHA" ] || { echo "Could not resolve branch $BASE_REF." >&2; exit 1; }
fi
if [ -z "$BASE_SHA" ]; then
  if git rev-parse -q --verify "$CANDIDATE_SHA^2" >/dev/null && has_simdjson "$CANDIDATE_SHA^2"; then
    BASE_SHA=$(git rev-parse "$CANDIDATE_SHA^2")
  else
    REMOVAL=$(git log -1 --format=%H --diff-filter=D "$CANDIDATE_SHA" -- deps/simdjson/simdjson.h)
    [ -n "$REMOVAL" ] || { echo "No commit removing deps/simdjson is reachable from $CANDIDATE_SHA; pass base_sha." >&2; exit 1; }
    BASE_SHA=$(git rev-parse "$REMOVAL^")
  fi
fi
echo "Baseline (simdjson): $BASE_SHA"
echo "Candidate (Jsonifier): $CANDIDATE_SHA"

echo "configs=$(jq -c --arg leg "$LEG" 'map(select(.name == $leg))' "$LEGS_FILE")" >> "$GITHUB_OUTPUT"
echo "legs=$(jq -c 'map(.name)' "$LEGS_FILE")" >> "$GITHUB_OUTPUT"
echo "base_sha=$BASE_SHA" >> "$GITHUB_OUTPUT"
echo "candidate_sha=$CANDIDATE_SHA" >> "$GITHUB_OUTPUT"
