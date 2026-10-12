#!/bin/bash
# BUG-7 (Advisor 1.7.0 / recipes 1.7.6): the first forced apply step on this
# multi-module project HANGS instead of failing. The prepended
# `process-test-classes` phase runs the project's own rewrite-maven-plugin
# execution (6.8.0, bound to `validate`) with Advisor's -Drewrite.* user
# properties (the BUG-2b hijack). With recipes 1.7.6 that old-core plugin
# recurses while building recipe descriptors:
#   com.vmware.tanzu.spring.recipes.boot40.UpgradeJackson_2_3_ApiOnly.getRecipeList
#   -> org.openrewrite.config.Environment.activateRecipes
#   -> ClasspathScanningLoader.ensureScanned -> full ClassGraph scan
#   -> scanYaml -> listRecipeDescriptors -> Recipe.getDescriptor -> getRecipeList -> ...
# one full classpath scan per level, depth 32 -> 35 in two minutes, 7 cores,
# 4 GB, never finishes (observed > 62 min). On 1.6.7 / recipes 1.7.5 the same
# step succeeded in 39 s (see transcript.txt); the Boot-4 step then failed
# cleanly (BUG-2a/2b).
#
# This script bounds the run to CAP seconds (default 600), samples the Maven
# child's main-thread recursion depth, then kills everything and resets the
# repro. Variant evidence (single module passes step 1, multi-module without
# plugin <dependencies> still hangs, Advisor's own plugin never recurses) is
# in variants-1.7.0.txt; a full thread dump is in hang-jstack-full-1.7.0.txt.
# Requires: advisor CLI on PATH, Maven, network, valid Spring Enterprise
# subscription credentials in ~/.m2/settings.xml, jstack (any JDK).
set -u
cd "$(dirname "$0")" || exit 1
CAP="${CAP:-600}"
rm -rf target app/target .advisor

echo "=== apply 1: --accept-no-alignment, capped at ${CAP}s (EXPECT on 1.7.0: never finishes) ==="
start=$(date +%s)
advisor upgrade-plan apply --accept-no-alignment </dev/null &
adv=$!
while kill -0 "$adv" 2>/dev/null; do
  sleep 60
  elapsed=$(( $(date +%s) - start ))
  mvn_pid=$(pgrep -f 'rewrite-maven-plugin:[0-9.]+:runNoFork' | head -1)
  if [ -n "$mvn_pid" ]; then
    depth=$(jstack "$mvn_pid" 2>/dev/null | awk '/^"main"/{p=1} p&&/^$/{exit} p' | grep -c 'UpgradeJackson_2_3_ApiOnly.getRecipeList')
    echo ">>> t=${elapsed}s maven pid ${mvn_pid}: recursion depth=${depth} $(ps -o pcpu=,rss= -p "$mvn_pid" | awk '{printf "cpu=%s%% rss=%dMB", $1, $2/1024}')"
  fi
  if [ "$elapsed" -ge "$CAP" ]; then
    echo ">>> cap reached after ${elapsed}s — killing advisor and its Maven child"
    pkill -f 'rewrite-maven-plugin:[0-9.]+:runNoFork'; kill "$adv" 2>/dev/null; sleep 2; kill -9 "$adv" 2>/dev/null
    break
  fi
done
wait "$adv" 2>/dev/null; echo "exit=$?"
echo "--- pom parent after the run (EXPECT: unchanged 3.4.5 — nothing was applied) ---"
grep -A1 'spring-boot-starter-parent' pom.xml | grep version
rm -rf target app/target .advisor
