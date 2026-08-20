# BUG-2b — `apply` inherits the project's own rewrite-maven-plugin declaration (dependencies + executions) and dies on it

| | |
|---|---|
| Type | Defect |
| Advisor | 1.6.7, `rewrite-maven-plugin` 6.44.0, recipes 1.7.5 |
| Verified | 2026-08-20, isolated minimal projects + original repo copy |
| Repro | [`repros/02-missing-recipe-bundle/`](../../repros/02-missing-recipe-bundle) (shared with BUG-2a) |

## Summary

`upgrade-plan apply` runs its OpenRewrite step through the project's own Maven build, so an
entirely ordinary `rewrite-maven-plugin` declaration in the project's pom breaks Advisor's
apply through **two vectors**:

**V1 — plugin `<dependencies>` downgrade (hits Advisor's own invocation, any module
layout).** Maven applies the pom's plugin declaration (matched by groupId:artifactId) to
CLI-invoked goals of the same plugin — including its `<dependencies>`. A typical pinned
recipe set like `org.openrewrite.recipe:rewrite-spring:6.7.0` pulls
`rewrite-java-dependencies:1.34.0`, which **predates**
`org.openrewrite.java.dependencies.search.ModuleHasDependency` (verified: the class is
absent from 1.34.0 and present in 1.54.2). Since Advisor's assembled recipe coordinates
don't pin `rewrite-java-dependencies` at all (BUG-2a), dependency mediation lets the pom's
older version win, and Advisor's **own**
`rewrite-maven-plugin:6.44.0:runNoFork (default-cli)` fails recipe validation on the
Spring Boot 4 step:

```
[ERROR] Recipe validation error in com.vmware.tanzu.MainAdvisorRecipe for property
        com.vmware.tanzu.AnyOfScanningRecipes: Unable to load Recipe: ...
        Recipe class not found: org.openrewrite.java.dependencies.search.ModuleHasDependency
```

**V2 — lifecycle execution hijack (multi-module).** For multi-module projects Advisor
prepends the `process-test-classes` phase to its invocation (single-module gets goal-only;
both command lines captured from live runs). The phase runs the project's own phase-bound
rewrite execution, which inherits Advisor's `-Drewrite.activeRecipes=MainAdvisorRecipe`,
`-Drewrite.configLocation`, `-Drewrite.failOnInvalidActiveRecipes=true` user properties —
i.e. the project's (older) plugin is silently re-pointed at Advisor's recipe program and
fails on **its** classpath (bare 6.8.0: "required class missing …ProjectIdentity"; with
recipe deps: the ModuleHasDependency error above, attributed to
`rewrite-maven-plugin:6.8.0:run (run-openrewrite)`).

## Verified configurations (all Advisor 1.6.7, Boot 3.4.5 → 4.x via `apply --accept-no-alignment`)

| Project shape | Outcome |
|---|---|
| Single-module, no rewrite plugin (also: with tests / JUnit 4 / spring-kafka) | ✅ upgrades to 4.1.x |
| Single-module, plugin + phase-bound execution, **no** plugin `<dependencies>` | ✅ upgrades to 4.1.x (goal-only invocation; V1 not armed, V2 not triggered) |
| Single-module, plugin **with** `<dependencies>` (rewrite-spring 6.7.0 …) | 💥 V1: Advisor's own 6.44.0 fails, `ModuleHasDependency` |
| Multi-module, no plugin | ✅ upgrades to 4.1.x |
| Multi-module, plugin + execution, no deps | 💥 V2: project's 6.8.0 fails, `ProjectIdentity` |
| Multi-module, plugin + execution + deps (= the original repo's setup) | 💥 V2 first: project's 6.8.0 fails, `ModuleHasDependency` (repro `transcript.txt`) |
| Original repo, execution neutralized (phase `none`), deps kept | 💥 V1: Advisor's own 6.44.0 fails, `ModuleHasDependency` |
| **Original repo, whole plugin declaration removed** | ✅ **entire 19-project plan applies** — spring-boot 3.4.x → 4.1.x, spring-kafka → 4.1.x, jackson 2 → 3, kafka → 4.3.x, with real source/pom/config changes across all modules |

The last row is the **workaround**: remove (or profile-guard) the project's own
`rewrite-maven-plugin` declaration — the executions *and* the `<dependencies>` — while
running Advisor. Neutralizing the execution alone is NOT sufficient (V1 remains).

## Expected

- Advisor's rewrite invocation should be isolated from the project's own rewrite-maven-plugin
  declaration: don't let pom plugin `<dependencies>` alter the recipe classpath (pinning
  `rewrite-java-dependencies` in the coordinates — BUG-2a — removes the known instance),
  and don't run project-bound rewrite executions with Advisor's `-Drewrite.*` overrides.
- Pre-flight: detect a rewrite-maven-plugin declaration in the project and warn with the
  workaround, instead of failing with "open a support ticket".

## Impact

Any project that runs OpenRewrite as part of its normal build — a very common setup — fails
`upgrade-plan apply` at the Boot 4 step with a message that blames Advisor's recipes rather
than the interaction. This was the actual failure mode of the original reproduction repo,
previously believed project-independent and non-workaroundable.
