# Broadcom support ticket — Spring Application Advisor 1.6.5 / 1.6.7

> Submission-ready draft. File at **https://support.broadcom.com** (Tanzu → Spring Application
> Advisor). These are two related, reproducible defects; they can be filed as one ticket with two
> parts or split into two. Both are **Advisor-side** — independent of the customer project, the
> Confluent/Kafka custom mappings, and subscription authentication.

---

## Summary

Upgrading an ordinary multi-module Spring Boot **3.4.5** Spring-Kafka application with Application
Advisor **1.6.5** cannot complete. After curated custom mappings unblock the Kafka/Confluent
dependency families (so `upgrade-plan get` produces a full 21-project plan including
`spring-boot 3.4.x → 4.1.x`), **no file-changing upgrade can be applied** because of two defects:

1. **`upgrade-plan apply` loops forever on a transitive-only, version-managed dependency** and never
   advances (no files ever change).
2. The only flag that escapes that loop — `apply --accept-no-alignment` — **fails recipe validation
   because Advisor's own recipe bundle references a recipe class it does not ship.**

## Severity / impact

High. For any project that reaches a real apply through this recipe path, the automated upgrade
**cannot produce source changes**. Both walls are in Advisor; neither is user-workaroundable.

## Environment

| | |
|---|---|
| Application Advisor | **1.6.5**; both defects **re-verified on 1.6.7** (2026-08-10, valid subscription token) |
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
`rewrite-java-dependencies` dependency survived a recipe release.

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

### Expected

`MainAdvisorRecipe` should validate and run. Fixes:

- Add `rewrite-java-dependencies` (matching version) to the assembled
  `-Drewrite.recipeArtifactCoordinates`, or stop referencing `ModuleHasDependency` from
  `AnyOfScanningRecipes`.
- Add a bundle smoke test (load all first-party recipes) so a self-referential
  "recipe class not found" can never ship.
- Make the failure actionable: name the missing recipe class and the module that provides it, instead
  of *"open a support ticket."*

---

## Attachments to include when filing

- The full `.advisor/errors/<timestamp>.log` from a `--accept-no-alignment` run (contains the failing
  `runNoFork` command line and the recipe-validation stack trace).
- The reproduction repo/branch above.
- This project's `docs/advisor-improvements.md` §4.9 and §4.10 (fuller analysis and additional
  advisor UX findings).
