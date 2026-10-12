# BUG-8 — with a custom `override` mapping for `spring-boot`, the forced 4.0.x → 4.1.x step pins the starters and leaves the parent behind

| | |
|---|---|
| Type | Defect (apply semantics with an incomplete override mapping) + hardening request |
| Advisor | **1.7.0**, recipes 1.7.6 |
| Verified | 2026-10-12, original repo from Boot 3.4.5 and from 4.0.8; isolation runs with/without the override |
| Evidence | [`evidence-1.7.0/C-pass2-pom-changes.diff`](evidence-1.7.0/C-pass2-pom-changes.diff) (with override), [`BUG8-no-override-pom-changes.diff`](evidence-1.7.0/BUG8-no-override-pom-changes.diff) (without), [`BUG8-minimal-repro.log`](evidence-1.7.0/BUG8-minimal-repro.log) (minimal app) |

## Summary

This repo wires a custom mapping `spring-boot-jackson3.json` with `MERGE_STRATEGY=override` for the
`spring-boot` project. It was written for Advisor 1.6.x to force the Jackson 3 alignment and only
defines the generations **3.5.x and 4.0.x** (4.0.x has no `nextRewrite`). On 1.7.0 the plan still
offers `spring-boot 4.0.x → 4.1.x` (the catalog's knowledge leaks through), and `apply
--accept-no-alignment` reports success — but what it writes is:

- every `spring-boot-starter-*` / `spring-boot-configuration-processor` dependency gets an explicit
  `<version>4.1.1</version>` (41 pins across 6 modules, +53 lines, 0 deletions);
- the `spring-boot-starter-parent` **stays at 4.0.8**;
- the resolved tree is starters 4.1.1 on top of Boot core modules 4.0.8 (`spring-boot-webmvc`,
  `spring-boot-tomcat`, `spring-boot-test` …). The build passes, so nothing flags it;
- the next forced step offers the same list again and changes **0 files** ("Successfully applied").

From Boot 3.4.5 the same thing happens inside the single forced step: parents land on 4.0.8 and 18
starters are pinned to 4.1.1 (`A-pom-yml-changes.diff`).

**Without the override mapping** (everything else identical) the same step moves the six parents
`4.0.8 → 4.1.1`, adds one `micrometer-tracing.version` property, pins nothing, and the reactor builds
with Boot 4.1.1 / spring-kafka 4.1.1 / `tools.jackson` 3.1.5. A minimal single-module app with no custom
mappings also goes 3.4.5 → 3.5.17 → 4.0.8 → **4.1.1 parent** cleanly in three forced steps.

## Why it is still Advisor's bug

An override mapping that does not know the target generation should make Advisor either refuse the
step (*"spring-boot 4.1.x is not defined in the active mapping"*) or fall through to the catalog
mapping for that generation. Instead it silently takes a third path — pinning each managed dependency
to the target version while leaving the parent on the old generation — and reports success. The
result is a mixed-generation build that compiles and is only visible in `git diff`.

## Expected

- Validate that the project being upgraded has a definition for the target generation in the
  *effective* mapping before applying; error out otherwise.
- Never pin BOM-managed `spring-boot-*` dependencies individually when the project uses the
  `spring-boot-starter-parent` (or a Boot BOM); move the parent/BOM.
- Warn when `<version>` elements are added to dependencies that were previously version-managed.

## Workaround (applied in this repo and the kit)

Leave `spring-boot-jackson3.json` **unwired** on Advisor 1.7.x (`order.txt` keeps it as a comment).
1.7.0 reaches Jackson 3 on its own. If a run has already produced the pins: remove them and move the
parent to 4.1.x by hand, or revert and re-run without the override.
