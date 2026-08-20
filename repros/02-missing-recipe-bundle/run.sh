#!/bin/bash
# Repro: on a MULTI-MODULE project, `advisor upgrade-plan apply` (here forced
# through the whole plan with --accept-no-alignment) invokes
#   mvn -B process-test-classes org.openrewrite.maven:rewrite-maven-plugin:<v>:runNoFork \
#       -Drewrite.activeRecipes=com.vmware.tanzu.MainAdvisorRecipe \
#       -Drewrite.configLocation=.advisor/<uuid>-rewrite.yml \
#       -Drewrite.failOnInvalidActiveRecipes=true \
#       -Drewrite.recipeArtifactCoordinates=com.vmware.tanzu.spring.recipes:...   (no rewrite-java-dependencies)
# The `process-test-classes` lifecycle phase runs the project's OWN
# rewrite-maven-plugin execution (bound to `validate` — an ordinary setup),
# which inherits all of Advisor's -Drewrite.* user properties and tries to load
# MainAdvisorRecipe itself. The Spring Boot 4 recipes reference
# org.openrewrite.java.dependencies.search.ModuleHasDependency, whose module
# (org.openrewrite.recipe:rewrite-java-dependencies) is NOT in the coordinates
# Advisor passes — so the project's plugin fails recipe validation and the
# whole apply aborts:
#   Recipe validation error in com.vmware.tanzu.AnyOfScanningRecipes: ...
#   Recipe class not found: org.openrewrite.java.dependencies.search.ModuleHasDependency
#
# Controls that make this precise (all verified 2026-08-20):
#  - Multi-module WITHOUT the rewrite-maven-plugin block: upgrades 3.4.5 ->
#    4.1.x successfully.
#  - Same app as ONE module with the plugin block but NO plugin <dependencies>:
#    also succeeds (goal-only invocation; the pom's plugin deps are what
#    downgrade rewrite-java-dependencies to 1.34.0, which predates the class —
#    see docs/reports/BUG-2a/BUG-2b).
#  - ONE module WITH the plugin <dependencies>: fails at Advisor's OWN
#    6.44.0:runNoFork (default-cli) with the same ModuleHasDependency error —
#    the downgrade vector needs no multi-module and no execution.
#  - The first apply step (Boot 3.5 recipes) succeeds even here; the failure
#    hits at the Boot 4 step, whose recipes carry the ModuleHasDependency
#    preconditions.
#  - Workaround: remove/guard the ENTIRE rewrite-maven-plugin declaration
#    (executions AND <dependencies>) while running Advisor; neutralizing the
#    execution alone is not sufficient.
# Run from this directory. Requires: advisor CLI on PATH, Maven, network,
# valid Spring Enterprise subscription credentials (recipes download fine —
# auth is not the issue).
set -u
cd "$(dirname "$0")" || exit 1
rm -rf target app/target .advisor

echo "=== apply 1: --accept-no-alignment (EXPECT: Boot 3.4.x -> 3.5.x succeeds) ==="
advisor upgrade-plan apply --accept-no-alignment </dev/null
echo "exit=$?"

echo
echo "=== apply 2: --accept-no-alignment (EXPECT: Boot 4 step fails recipe validation) ==="
advisor upgrade-plan apply --accept-no-alignment </dev/null
echo "exit=$?"
echo "--- evidence from .advisor/errors ---"
grep -hE "Recipe class not found|Failed to execute goal|runNoFork" .advisor/errors/*.log 2>/dev/null | sort -u | head -5
