# BUG-2a — Recipe set references `ModuleHasDependency` but the assembled coordinates don't ship it

| | |
|---|---|
| Type | Defect (recipe packaging) |
| Advisor | 1.6.7, recipes **1.7.5**, `rewrite-maven-plugin` 6.44.0 |
| Verified | 2026-08-20, isolated minimal project |
| Repro | [`repros/02-missing-recipe-bundle/`](../../repros/02-missing-recipe-bundle) (shared with BUG-2b) |

## Summary

The Spring Boot 4 upgrade recipes shipped in
`com.vmware.tanzu.spring.recipes:spring-boot-4-upgrade-recipes:1.7.5` (and the boot-2 set)
reference `org.openrewrite.java.dependencies.search.ModuleHasDependency` — e.g.
`boot40/spring-boot-starter-zipkin-test.yml` uses it inside a
`com.vmware.tanzu.AnyOfScanningRecipes` precondition, and
`boot40/DisableLivenessReadinessProbes_4_0.yml` references it directly. That class lives in
**`org.openrewrite.recipe:rewrite-java-dependencies`**, which is **not** in the recipe
coordinates Advisor assembles for the run:

```
-Drewrite.recipeArtifactCoordinates=com.vmware.tanzu.spring.recipes:java-recipes:1.7.5,
  ...:rewrite-migrate-java:1.7.5, ...:rewrite-spring:1.7.5,
  ...:spring-boot-2-upgrade-recipes:1.7.5, ...:spring-boot-3-upgrade-recipes:1.7.5,
  ...:spring-boot-4-upgrade-recipes:1.7.5        ← no rewrite-java-dependencies
```

Because the module is never pinned, the `rewrite-java-dependencies` version that actually
lands on the classpath is left to Maven dependency mediation. On a clean project the tanzu
recipes' transitive **1.54.2** (which has the class) wins and everything works. But when the
project's own `rewrite-maven-plugin` declaration contributes plugin `<dependencies>` — e.g.
the very common `org.openrewrite.recipe:rewrite-spring:6.7.0`, which pins
`rewrite-java-dependencies:1.34.0`, a version that **predates the class** — mediation
downgrades it, and recipe validation fails (in Advisor's *own* 6.44.0 invocation, and in
the project's plugin execution that Advisor's multi-module invocation triggers — see
BUG-2b):

```
[ERROR] Recipe validation error in com.vmware.tanzu.AnyOfScanningRecipes: Unable to load
        Recipe: ... Recipe class not found:
        org.openrewrite.java.dependencies.search.ModuleHasDependency
```

Five instances per run (`error-stacktrace.log`), aborting the entire
`upgrade-plan apply --accept-no-alignment`.

## Reproduction

`repros/02-missing-recipe-bundle/run.sh` — see BUG-2b for the trigger mechanics. The
packaging defect itself is visible statically:

```console
$ unzip -p ~/.m2/repository/com/vmware/tanzu/spring/recipes/spring-boot-4-upgrade-recipes/1.7.5/spring-boot-4-upgrade-recipes-1.7.5.jar \
    'META-INF/rewrite/boot40/spring-boot-starter-zipkin-test.yml' | grep -A3 AnyOfScanningRecipes
  - com.vmware.tanzu.AnyOfScanningRecipes:
      recipes:
        - org.openrewrite.java.dependencies.search.ModuleHasDependency: ...
```

## Expected

- Add `org.openrewrite.recipe:rewrite-java-dependencies` (pinned to the version the
  recipes were built against) to the assembled `-Drewrite.recipeArtifactCoordinates`, so
  the class can never be lost to dependency mediation — or stop referencing
  `ModuleHasDependency` from the shipped recipes.
- Add a CI smoke test that loads every shipped recipe against exactly the advertised
  coordinate set; a first-party "Recipe class not found" should never ship. (This defect
  survived at least the 1.7.2 → 1.7.5 recipe releases.)
