#!/bin/bash
# Repro: two custom mappings sharing a slug are ACCEPTED by `build-config get`,
# REJECTED by `upgrade-plan get` (generic message), and CRASH `mapping create`
# (whose error log exposes the real cause: "Some projects were already defined").
# Run from this directory. Requires: advisor CLI on PATH, Maven, network.
set -u
cd "$(dirname "$0")" || exit 1
rm -rf target .advisor/errors

export SPRING_ADVISOR_MAPPING_CUSTOM_0_FILEPATH="$PWD/mappings/demo-a.json"
export SPRING_ADVISOR_MAPPING_CUSTOM_1_FILEPATH="$PWD/mappings/demo-b.json"

echo "=== 1. build-config get (EXPECT: succeeds — duplicate slug tolerated) ==="
advisor build-config get </dev/null
echo "exit=$?"

echo
echo "=== 2. upgrade-plan get (EXPECT: fails validating the SECOND same-slug mapping) ==="
advisor upgrade-plan get </dev/null
echo "exit=$?"

echo
echo "=== 3. mapping create for a covered coordinate (EXPECT: crash; error log has root cause) ==="
advisor mapping create -c=org.apache.commons:commons-lang3 </dev/null
echo "exit=$?"
echo "--- root cause from .advisor/errors ---"
grep -h "Caused by" .advisor/errors/*.log 2>/dev/null | tail -2
