# Broadcom support ticket — Spring Application Advisor 1.6.5 / 1.6.7

> Submission-ready draft. File at **https://support.broadcom.com** (Tanzu → Spring Application
> Advisor). These are three related, reproducible defects; they can be filed as one ticket with
> three parts or split. All are **Advisor-side** — independent of the customer project, the
> Confluent/Kafka custom mappings, and subscription authentication.

---

## Summary

Upgrading an ordinary multi-module Spring Boot **3.4.5** Spring-Kafka application with Application
Advisor **1.6.5** (re-verified on **1.6.7**) cannot complete. After curated custom mappings unblock the Kafka/Confluent
dependency families (so `upgrade-plan get` produces a full 21-project plan including
`spring-boot 3.4.x → 4.1.x`), **no file-changing upgrade can be applied** because of two defects:

1. **`upgrade-plan apply` loops forever on a transitive-only, version-managed dependency** and never
   advances (no files ever change).
2. The only flag that escapes that loop — `apply --accept-no-alignment` — **fails recipe validation
   because Advisor's own recipe bundle references a recipe class it does not ship.**
   *(Re-scoped 2026-08-20 after isolated-repro bisection: the failure triggers via the customer
   project's own `rewrite-maven-plugin` declaration — Defect 2 below has the corrected mechanism,
   a verified-configuration matrix, and a workaround. It remains an Advisor-side defect: the
   recipe set relies on an unpinned `rewrite-java-dependencies` and Advisor's `-Drewrite.*`
   configuration leaks into project plugin executions.)*

A third defect (1.6.7) affects the mapping-authoring path that leads up to the plan:
`mapping create` output for sibling modules of one family shares a slug, and **`build-config get`
accepts duplicate-slug mappings while `upgrade-plan get` rejects them** — so the mappings Advisor
generates cannot be composed into a working plan (Defect 3).

## Severity / impact

High. On the default incremental path the automated upgrade **cannot produce source changes**
(Defect 1, not user-workaroundable). The forced path fails for any project that declares its own
`rewrite-maven-plugin` (Defect 2) — workaroundable only by removing that declaration while Advisor
runs (verified 2026-08-20: with it removed, the full 19-project plan applies end-to-end on this
repo). Defect 3 can only be worked around by hand-curating a single consolidated family mapping in
place of Advisor's own generated ones. All three defects are in Advisor.

## Environment

| | |
|---|---|
| Application Advisor | **1.6.5**; Defects 1–2 **re-verified on 1.6.7** (2026-08-10, valid subscription token); Defect 3 observed on **1.6.7** (2026-08-11) |
| Java | 21 |
| Build | Maven wrapper `mvnw` 3.9.9 |
| Project | Spring Boot 3.4.5, multi-module, `spring-kafka` (BOM-managed), `io.confluent:*` 7.9.1 |
| Recipe artifacts loaded by Advisor | 1.6.5: `com.vmware.tanzu.spring.recipes:{java-recipes, rewrite-hibernate, rewrite-migrate-java, rewrite-spring, rewrite-testing-frameworks, spring-boot-2-upgrade-recipes, spring-boot-3-upgrade-recipes, spring-boot-4-upgrade-recipes}:1.7.2 — 1.6.7: same set minus `rewrite-hibernate`/`rewrite-testing-frameworks`, at **1.7.5** |
| Rewrite plugin (Advisor invocation) | 1.6.5: `rewrite-maven-plugin:6.38.0:runNoFork` — 1.6.7: `6.44.0:runNoFork` |
| Reproduction repo | `github.com/dcaron/spring-io-barcelona-2025-spring-kafka-the-advance-features`, branch `advisor` |

**Re-verification on 1.6.7:** Defect 1 reproduces identically (`apply` selects
`commons-beanutils 1.9.x → 1.11.x` on every run, reports success, changes 0 files). Defect 2
reproduces identically with the **newer 1.7.5 recipe set** — `MainAdvisorRecipe →
AnyOfScanningRecipes` still fails with *"Recipe class not found:
org.openrewrite.java.dependencies.search.ModuleHasDependency"* — i.e. the missing
`rewrite-java-dependencies` dependency survived a recipe release. Defect 3 is **1.6.7-specific**:
on 1.6.5 the same wiring failed earlier and harder, as a `build-config get` abort
(`RaiseErrorOnDuplicatesCoordinatesMerger`).

Subscription auth is **working** (commercial recipes download fine); this is not a 401/credentials
issue.

---

## Defect 1 — `upgrade-plan apply` loops on a transitive-only, version-managed project

### What happens

With the plan fully unblocked, every `advisor upgrade-plan apply` selects the same bottom-of-tree
project and changes nothing:

```console
$ advisor upgrade-plan apply        # run repeatedly — identical every time
Projects to upgrade:
    * commons-beanutils from 1.9.x to 1.11.x
👍 Successfully applied upgrade.     # …but 0 files changed
```

`commons-beanutils` is **not declared in any pom** — it is purely transitive (via
`commons-validator`). There is no version to rewrite, so the apply is a no-op; the resolved version
stays `1.9.x`, so the same step reappears on every re-plan. Verified by driving `apply` **six times
in a row**: each prints *"Successfully applied upgrade,"* each re-selects `commons-beanutils`, each
changes nothing, and each regenerates `build-config.json` only to pick it again. Advisor never
reaches `spring-boot` / `spring-kafka` / `jackson`.

`--force` and `--squash=N` do **not** help (they still apply "the first step," which resolves to the
same no-op).

**Isolated minimal reproduction (2026-08-20):** `repros/01-apply-noop-loop/` — a one-pom project
whose only dependency is `commons-validator:1.7` (pulling `commons-beanutils:1.9.4` transitively)
plus two mapping fixtures; three consecutive applies each select `commons-beanutils 1.9.x → 1.11.x`,
report success, and change zero files. See `docs/reports/BUG-1-apply-noop-loop.md`.

### Expected

An apply that changes no files and leaves the selected project's resolved version unchanged should be
treated as non-actionable — advance to the next candidate, or stop with a clear message (e.g. *"no
further file-changing steps; N projects remain BOM-managed/transitive"*) — not loop while reporting
success. Ideally, a transitive-only / version-managed artifact should never be surfaced as a
standalone apply step (upgrade it via the direct dependency or BOM that pulls it in).

---

## Defect 2 — forced full-plan apply fails: `MainAdvisorRecipe` references a recipe class it does not ship

### What happens

`advisor upgrade-plan apply --accept-no-alignment` (the only way past Defect 1) drives the whole plan
and launches the real OpenRewrite Boot-4 run, then aborts during recipe **validation**:

```console
$ advisor upgrade-plan apply --accept-no-alignment
[ERROR] Recipe validation error in com.vmware.tanzu.MainAdvisorRecipe for property
        com.vmware.tanzu.AnyOfScanningRecipes: Unable to load Recipe:
        java.lang.IllegalArgumentException: Cannot construct instance of
        `com.vmware.tanzu.AnyOfScanningRecipes`, problem:
        Recipe class not found: org.openrewrite.java.dependencies.search.ModuleHasDependency
[ERROR] Failed to execute goal org.openrewrite.maven:rewrite-maven-plugin:6.38.0:runNoFork
        (default-cli) on project ...: Recipe validation errors detected as part of one or more
        activeRecipe(s).
💔 Could not apply the recipe(s) to upgrade your Spring projects. You can find the error in
   .advisor/errors/<timestamp>.log - Please open a new support ticket ...
```

`org.openrewrite.java.dependencies.search.ModuleHasDependency` is provided by
**`org.openrewrite.recipe:rewrite-java-dependencies`**, which is **not** among the recipe coordinates
Advisor assembles for the run (listed in the Environment table). So Advisor's own
`MainAdvisorRecipe → AnyOfScanningRecipes` references a class its own bundled classpath lacks.

### Proof it is Advisor-side (not the project)

The customer project also configures `rewrite-maven-plugin` 6.8.0 (a `validate`-phase execution).
To rule it out, we set that execution's phase to `none` and re-ran: **identical error**, now
attributed to Advisor's own `rewrite-maven-plugin:6.38.0:runNoFork` instead of the project's
`6.8.0:run`. The missing class is in Advisor's recipe set, not the project.

### Corrected mechanism (2026-08-20, isolated-repro bisection — supersedes the paragraph above)

The failure is **triggered by the project's own `rewrite-maven-plugin` declaration**, in two ways
(clean Boot 3.4.5 apps, single- or multi-module, upgrade to 4.1.x successfully with the same
Advisor and recipe versions):

1. **Plugin `<dependencies>` downgrade — this is why neutralizing the execution didn't help.**
   Maven merges the pom's plugin `<dependencies>` into *any* invocation of the same plugin,
   including Advisor's CLI-forced `6.44.0:runNoFork`. The project pins
   `org.openrewrite.recipe:rewrite-spring:6.7.0`, which pulls
   `rewrite-java-dependencies:1.34.0` — a version that predates
   `org.openrewrite.java.dependencies.search.ModuleHasDependency` (class verified absent in
   1.34.0, present in 1.54.2). Advisor never pins `rewrite-java-dependencies` in its
   coordinates, so mediation lets the project's older version win and validation fails.
2. **Execution hijack (multi-module).** For multi-module projects Advisor invokes
   `mvn -B process-test-classes …:runNoFork -Drewrite.activeRecipes=com.vmware.tanzu.MainAdvisorRecipe
   -Drewrite.configLocation=… -Drewrite.failOnInvalidActiveRecipes=true`; the lifecycle phase runs
   the project's own phase-bound rewrite execution, which inherits those `-Drewrite.*` user
   properties and attempts Advisor's recipe program on its own plugin version/classpath.

**Workaround (verified):** remove or profile-guard the entire project `rewrite-maven-plugin`
declaration (executions *and* `<dependencies>`) while running Advisor — on a copy of this repo the
full 19-project `apply --accept-no-alignment` then completes with real source changes in every
module. Minimal reproduction (parent + 1 module, ~80-line poms) and a verified-configuration
matrix: `repros/02-missing-recipe-bundle/` and `docs/reports/BUG-2a`/`BUG-2b` in the repro repo.

### Expected

`MainAdvisorRecipe` should validate and run. Fixes:

- Add `rewrite-java-dependencies` (pinned to the version the recipes are built against) to the
  assembled `-Drewrite.recipeArtifactCoordinates` so mediation can never downgrade it, or stop
  referencing `ModuleHasDependency` from `AnyOfScanningRecipes`.
- Isolate Advisor's rewrite invocation from the project's own `rewrite-maven-plugin`
  declaration (don't inherit its plugin `<dependencies>`; don't run its executions with
  Advisor's `-Drewrite.*` overrides), or pre-flight-detect the declaration and tell the user.
- Add a bundle smoke test (load all first-party recipes) so a self-referential
  "recipe class not found" can never ship.
- Make the failure actionable: name the missing recipe class and the module that provides it, instead
  of *"open a support ticket."*

---

## Defect 3 — duplicate-slug custom mappings: `build-config get` accepts them, `upgrade-plan get` rejects them (1.6.7)

### What happens

On 1.6.7, `mapping create` for sibling modules of one release train emits mappings that share a
slug — e.g. `-c=org.apache.kafka:kafka-metadata` and `-c=org.apache.kafka:kafka-storage` each
produce a mapping with slug `kafka` (15 runs across the `org.apache.kafka:*` family collapse onto
just 3 slugs: `kafka` ×9, `kafka-clients` ×1, and the empty slug ×5). Wiring more than one of them
via `SPRING_ADVISOR_MAPPING_CUSTOM_N_FILEPATH` behaves **inconsistently between commands**:

```console
$ advisor build-config get          # two mappings with slug "kafka" wired
🚀 The build-configuration has been generated in …/target/.advisor/build-config.json   # OK

$ advisor upgrade-plan get
🏃 [ 1 / 2 ] Validating syntax of upgrade mappings … error
💔 Errors
- <project> failed with the following message:
🔎 Failed to load an additional upgrade mapping from '…/kafka-metadata-mapping.json':
   Failed to load the mapping source. Please verify the source configuration.
```

The failure is always on the **second** mapping sharing a slug (same result for two empty-slug
mappings). The message names the file — an improvement over 1.6.5's
`RaiseErrorOnDuplicatesCoordinatesMerger` hard abort — but the reason is generic, and there is no
union merge: at most **one mapping per slug** can be wired. Overlap on the same *coordinate* across
*different* slugs is, by contrast, tolerated by both commands.

**Root cause identified (2026-08-19/20).** `mapping create` also loads the wired custom mappings,
crashes on the same duplicate ("open a support ticket"), and its error log exposes what
`upgrade-plan get`'s generic message hides — the 1.6.5 merger error is still the underlying cause:

```
MappingSourceLoadException: Failed to load mapping source '…': Error merging mapping source …
Caused by: java.lang.IllegalArgumentException: Some projects were already defined: [kafka]
```

(at `MappingsLoader.buildReport`, `MappingsLoader.java:90`). So `build-config get` uses a tolerant
load path while `upgrade-plan get` and `mapping create` share the strict one. A fully synthetic,
Kafka-free reproduction (two 25-line same-slug fixtures, three commands, three different behaviors)
is in the repo: `repros/03-dup-slug-inconsistent-loading/` — see also `docs/reports/BUG-3-…`.

Consequence: the mappings Advisor itself generates for a module family cannot be combined. The best
duplicate-free combination of `mapping create` output covers 8 of the 15 `org.apache.kafka:*`
coordinates this project needs; the other 7 modules return to the blocked list (*"Please request
your administrator to configure the projects…"*). A hand-curated single-file family mapping remains
the only way through — verified 2026-08-11; full experiment (generated mappings + load-test logs)
in the reproduction repo under `.advisor/mappings-generated-1.6.7/`.

### Expected

- `build-config get` and `upgrade-plan get` should apply the **same** mapping-loading rules — a
  wiring that survives build-config should not fail at plan time.
- Same-slug mappings should **union-merge** (coordinates and rewrite tables) instead of being
  rejected, since `mapping create` itself emits same-slug files for siblings of one family; at
  minimum, the error should say *why* the mapping was rejected (duplicate slug `kafka`, already
  defined by `<file>`), not *"verify the source configuration."*

---

## Attachments to include when filing

- The full `.advisor/errors/<timestamp>.log` from a `--accept-no-alignment` run (contains the failing
  `runNoFork` command line and the recipe-validation stack trace).
- The reproduction repo/branch above.
- This project's `docs/advisor-improvements.md` §4.9 and §4.10 (fuller analysis and additional
  advisor UX findings), and §1c plus `.advisor/mappings-generated-1.6.7/README.md` for Defect 3
  (the generated mappings and load-test logs).
