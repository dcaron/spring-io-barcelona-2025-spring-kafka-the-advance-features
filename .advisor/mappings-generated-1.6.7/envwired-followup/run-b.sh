#!/bin/bash
# run-b.sh <run-name> <coordinate> [extra mapping filepaths...]
# Same as run-one.sh but WITHOUT apache-kafka.json in the baseline env.
set -u
PROJ=/Users/dcaron/Documents/src/spring-io-barcelona-2025-spring-kafka-the-advance-features
BASE=/private/tmp/claude-501/-Users-dcaron-Documents-src-spring-io-barcelona-2025-spring-kafka-the-advance-features/78d5aec3-9d23-474c-8812-a9f043c46bb3/scratchpad/envwired

name="$1"; coord="$2"; shift 2
rundir="$BASE/runs/$name"
mkdir -p "$rundir"
cd "$rundir" || exit 1

export SPRING_ADVISOR_MAPPING_CUSTOM_0_FILEPATH="$PROJ/.advisor/mappings/spring-boot-jackson3.json"
export SPRING_ADVISOR_MAPPING_CUSTOM_0_MERGE_STRATEGY=override
export SPRING_ADVISOR_MAPPING_CUSTOM_1_FILEPATH="$PROJ/.advisor/mappings/javafaker.json"
export SPRING_ADVISOR_MAPPING_CUSTOM_2_FILEPATH="$PROJ/.advisor/mappings/avro.json"
export SPRING_ADVISOR_MAPPING_CUSTOM_3_FILEPATH="$PROJ/.advisor/mappings/confluent-platform.json"
idx=4
for extra in "$@"; do
  export "SPRING_ADVISOR_MAPPING_CUSTOM_${idx}_FILEPATH=$extra"
  idx=$((idx + 1))
done

env | grep SPRING_ADVISOR | sort
echo "--- advisor mapping create -c=$coord (cwd=$rundir) ---"
advisor mapping create -c="$coord" </dev/null 2>&1
echo "exit=$?"
echo "--- output files ---"
ls -la .advisor/mappings/ 2>/dev/null
for f in .advisor/mappings/.json .advisor/mappings/*.json; do
  [ -f "$f" ] && echo "== $f ==" && python3 -c "
import json
d=json.load(open('$f'))
print('slug:', repr(d.get('slug')))
print('coordinates:', d.get('coordinates'))
"
done
