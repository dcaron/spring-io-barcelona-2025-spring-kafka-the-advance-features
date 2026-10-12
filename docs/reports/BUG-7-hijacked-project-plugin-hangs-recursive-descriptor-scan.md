# BUG-7 — on 1.7.0 the hijacked project rewrite plugin no longer fails, it hangs (recursive recipe-descriptor scan)

| | |
|---|---|
| Type | Defect (regression of the BUG-2b symptom) |
| Advisor | **1.7.0**, recipes **1.7.6**, `rewrite-maven-plugin` 6.44.0 (project plugin 6.8.0) |
| Verified | 2026-10-12, isolated minimal multi-module project + original repo (unguarded worktree) |
| Repro | [`repros/02-missing-recipe-bundle/run-1.7.0-hang.sh`](../../repros/02-missing-recipe-bundle/run-1.7.0-hang.sh) (bounded; evidence files `hang-*-1.7.0.txt`, `variants-1.7.0.txt`) |

## Summary

The BUG-2b vector is unchanged: on a multi-module project `upgrade-plan apply` runs
`mvn process-test-classes …rewrite-maven-plugin:6.44.0:runNoFork -Drewrite.*`, and the
prepended phase executes the project's **own** `rewrite-maven-plugin` execution with Advisor's
`-Drewrite.activeRecipes=com.vmware.tanzu.MainAdvisorRecipe` / `-Drewrite.recipeArtifactCoordinates`
user properties. On 1.6.7 (recipes 1.7.5) that execution failed recipe validation at the Boot-4
step after the Boot 3.5 step had succeeded. On 1.7.0 (recipes 1.7.6) it **hangs at the first
step** — `Boot 3.4.x → 3.5.x` — and never returns:

- repro 02 as committed: killed after **62 min** wall, 713 % CPU, 4.4 GB RSS (1.6.7: 39 s success);
- original repo, unguarded worktree: killed after 11 min at the same state (784 % CPU, 4.5 GB);
- a 600 s capped re-run shows the same.

The Maven child's main thread is recursing while building recipe descriptors (full dump in
`hang-jstack-full-1.7.0.txt`; depth grew from 32 to 35 in two minutes, each level a full
ClassGraph classpath scan with 19 worker threads):

```
com.vmware.tanzu.spring.recipes.boot40.UpgradeJackson_2_3_ApiOnly.getRecipeList(UpgradeJackson_2_3_ApiOnly.java:46)
  org.openrewrite.config.Environment.activateRecipes
  org.openrewrite.config.ClasspathScanningLoader.loadRecipe → ensureScanned → scanClasses (ClassGraph.scan)
  … → scanYaml → YamlResourceLoader.listRecipeDescriptors → Recipe.getDescriptor
  → DeclarativeRecipe.createRecipeDescriptor → Recipe.getDescriptor
  → UpgradeJackson_2_3_ApiOnly.getRecipeList → Environment.activateRecipes → …   (repeats)
```

The hung goal in the Maven log is the project's execution — `--- rewrite:6.8.0:run
(run-openrewrite) @ missing-recipe-repro-app ---` / `Using active recipe(s)
[com.vmware.tanzu.MainAdvisorRecipe]` — i.e. the 1.7.6 recipe jars are being loaded by the
project's older rewrite core, and `UpgradeJackson_2_3_ApiOnly.getRecipeList()` calling
`Environment.activateRecipes()` re-enters the classpath scan that is still enumerating it.

## What was bisected (all 1.7.0, `apply --accept-no-alignment`, same app)

| Layout | Step 1 (Boot 3.4→3.5) | Step 2 (Boot 3.5→4.0) |
|---|---|---|
| multi-module, plugin execution + plugin `<dependencies>` (as committed) | **HANG** | not reached |
| multi-module, plugin execution, **no** `<dependencies>` (pure BUG-2b) | **HANG** (600 s cap) | not reached |
| single module, plugin block with `<dependencies>` (goal-only invocation, execution does not run) | ok, 82 s | **fails** exactly as BUG-2a: `Recipe class not found: …ModuleHasDependency` (`error-stacktrace-single-module-1.7.0.log`) |
| control: no rewrite plugin at all (repro 01), Advisor's own 6.44.0 with recipes 1.7.6 | ok, 50 s | — |

So the recursion needs the project's old-core plugin execution; Advisor's own plugin loads
the same recipes fine, and BUG-2a is unchanged.

## Expected

- Advisor must not run project plugin executions with its own `-Drewrite.*` properties at all
  (BUG-2b expected behaviour): invoke the goal without a lifecycle phase, or isolate the properties.
- `UpgradeJackson_2_3_ApiOnly.getRecipeList()` should not call `Environment.activateRecipes()`
  (or the scan must be re-entrancy safe); a recipe-loading self-test under an older rewrite core
  would have caught the infinite recursion.
- A hard timeout on the rewrite step, with the Maven log surfaced, instead of silent spinning.

## Workaround

Unchanged from BUG-2b and now **mandatory**: move the whole `rewrite-maven-plugin`
declaration into an explicitly-activated profile (`advisor-kit/snippets/rewrite-plugin-profile-guard.xml`).
With the guard in place the full forced plan applies on 1.7.0 (`STATUS-1.7.0.md`, scenario A).
