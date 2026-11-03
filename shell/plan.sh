#!/usr/bin/env bash

set -eo pipefail
source "$(dirname "$0")/common.sh"

if [ -z "$JSONIFIER_SHA" ]; then
  JSONIFIER_SHA=$(git ls-remote "https://github.com/${JSONIFIER_REPOSITORY}.git" "refs/heads/${JSONIFIER_REF}" | awk '{print $1}')
fi
[ -n "$JSONIFIER_SHA" ] || { echo "Could not resolve ${JSONIFIER_REPOSITORY}@${JSONIFIER_REF}" >&2; exit 1; }
echo "Jsonifier ${JSONIFIER_REPOSITORY}@${JSONIFIER_REF} is $JSONIFIER_SHA"

echo "configs=$(jq -c --arg leg "$LEG" 'map(select(.name == $leg))' "$LEGS_FILE")" >> "$GITHUB_OUTPUT"
echo "legs=$(jq -c 'map(.name)' "$LEGS_FILE")" >> "$GITHUB_OUTPUT"
echo "jsonifier_sha=$JSONIFIER_SHA" >> "$GITHUB_OUTPUT"
