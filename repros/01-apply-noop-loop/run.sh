#!/bin/bash
# Repro: `upgrade-plan apply` selects a transitive-only dependency
# (commons-beanutils, never declared in the pom), reports success, changes no
# files, and re-selects the exact same step on every subsequent run.
# Run from this directory. Requires: advisor CLI on PATH, Maven, network,
# valid Spring Enterprise subscription credentials in ~/.m2/settings.xml.
set -u
cd "$(dirname "$0")" || exit 1
rm -rf target .advisor

# Custom mappings for the two projects advisor's catalog does not configure
# (commons-validator, commons-beanutils). Both fixtures live in ./mappings.
export SPRING_ADVISOR_MAPPING_CUSTOM_0_FILEPATH="$PWD/mappings/commons-validator.json"
export SPRING_ADVISOR_MAPPING_CUSTOM_1_FILEPATH="$PWD/mappings/commons-beanutils.json"

echo "=== upgrade-plan get ==="
advisor upgrade-plan get </dev/null
echo "exit=$?"

for i in 1 2 3; do
  echo
  echo "=== upgrade-plan apply — run $i (EXPECT: same project selected, 'Successfully applied', 0 files changed) ==="
  checksum_before=$(find . -name "*.xml" -newer /dev/null -exec md5 {} + 2>/dev/null | md5)
  advisor upgrade-plan apply </dev/null
  echo "exit=$?"
  checksum_after=$(find . -name "*.xml" -newer /dev/null -exec md5 {} + 2>/dev/null | md5)
  if [ "$checksum_before" = "$checksum_after" ]; then
    echo ">>> run $i changed NO project files (checksums identical)"
  else
    echo ">>> run $i CHANGED project files"
  fi
done
