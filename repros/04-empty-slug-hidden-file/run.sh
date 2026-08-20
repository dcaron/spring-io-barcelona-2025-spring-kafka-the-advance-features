#!/bin/bash
# Repro: `advisor mapping create` derives its output filename from the slug it
# computed itself. For org.apache.kafka:kafka_2.13 (and several other Kafka
# artifacts) the computed slug is the EMPTY STRING, so the mapping is written
# to `.advisor/mappings/.json` — a hidden dotfile. There is no -o/--output
# flag to control the destination, and a non-empty slug that matches an
# existing file silently overwrites it.
# Run from this directory. Requires: advisor CLI on PATH, network, Maven repo
# access for org.apache.kafka:kafka_2.13.
set -u
cd "$(dirname "$0")" || exit 1
rm -rf .advisor

echo "=== advisor mapping create -c=org.apache.kafka:kafka_2.13 ==="
advisor mapping create -c=org.apache.kafka:kafka_2.13 </dev/null
echo "exit=$?"

echo
echo "=== output (EXPECT: a hidden file literally named '.json') ==="
ls -la .advisor/mappings/
echo
echo "=== slug inside the file (EXPECT: empty string) ==="
python3 -c "
import json
d = json.load(open('.advisor/mappings/.json'))
print('slug:', repr(d['slug']))
print('coordinates:', d['coordinates'])
"
