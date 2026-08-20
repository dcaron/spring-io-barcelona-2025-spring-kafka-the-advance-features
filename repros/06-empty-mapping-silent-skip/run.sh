#!/bin/bash
# Repro: a wired custom mapping that is EMPTY (`{}`) is silently ignored.
# On 1.6.5 it aborted every command ("One of the custom mappings provided is
# empty" — without naming the file). On 1.6.7 build-config/upgrade-plan
# succeed, but there is NO warning naming the skipped file, so a typo'd or
# truncated mapping goes unnoticed and its project silently returns to the
# blocked list.
# Run from this directory. Requires: advisor CLI on PATH, Maven, network.
set -u
cd "$(dirname "$0")" || exit 1
rm -rf target

export SPRING_ADVISOR_MAPPING_CUSTOM_0_FILEPATH="$PWD/mappings/empty.json"

echo "=== build-config get with an empty '{}' mapping wired ==="
echo "    (EXPECT: succeeds; note the absence of any warning naming empty.json)"
advisor build-config get </dev/null
echo "exit=$?"
