#!/bin/bash
# Demonstration for the feature request "family-aware mapping create /
# union-merge": generating mappings for two SIBLING modules of one release
# train (Apache Kafka) produces two files with the SAME slug ("kafka") that
# both claim org.apache.kafka:kafka-clients — and such same-slug mappings
# cannot be wired together (upgrade-plan get and mapping create reject the
# second one; see also repro 03). So Advisor's own generated output cannot
# cover a module family: across all 15 org.apache.kafka:* coordinates this
# demo's parent project needs, generation collapses onto 3 slugs and the best
# legal combination covers 8 of 15 coordinates.
# Run from this directory. Requires: advisor CLI on PATH, network.
set -u
cd "$(dirname "$0")" || exit 1
rm -rf runs
mkdir -p runs/a runs/b

echo "=== 1. mapping create -c=org.apache.kafka:kafka-group-coordinator (in runs/a) ==="
( cd runs/a && advisor mapping create -c=org.apache.kafka:kafka-group-coordinator </dev/null ) | tail -2

echo
echo "=== 2. mapping create -c=org.apache.kafka:kafka-metadata (in runs/b) ==="
( cd runs/b && advisor mapping create -c=org.apache.kafka:kafka-metadata </dev/null ) | tail -2

echo
echo "=== 3. both runs produced slug 'kafka', both claim kafka-clients ==="
python3 - <<'EOF'
import json
for d in ('runs/a', 'runs/b'):
    m = json.load(open(f'{d}/.advisor/mappings/kafka.json'))
    print(f"{d}/.advisor/mappings/kafka.json -> slug {m['slug']!r}, coordinates {m['coordinates']}")
EOF

echo
echo "=== 4. wiring both files (EXPECT: rejected — 'Some projects were already defined: [kafka]') ==="
export SPRING_ADVISOR_MAPPING_CUSTOM_0_FILEPATH="$PWD/runs/a/.advisor/mappings/kafka.json"
export SPRING_ADVISOR_MAPPING_CUSTOM_1_FILEPATH="$PWD/runs/b/.advisor/mappings/kafka.json"
advisor mapping create -c=org.apache.kafka:kafka-group-coordinator </dev/null
echo "exit=$?"
grep -h "Caused by" .advisor/errors/*.log 2>/dev/null | tail -1
