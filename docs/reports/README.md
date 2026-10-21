# Advisor reports — one issue per file, one verified repro each

Every report below was verified on **Advisor 1.6.7** (2026-08-20) against an **isolated minimal
reproduction** under [`repros/`](../../repros), **re-verified on Advisor 1.7.0** (recipes 1.7.6) on
**2026-10-12** and **on Advisor 1.7.1 on 2026-10-21** — see each report's *"Status on Advisor 1.7.0"* /
*"… 1.7.1"* sections, the consolidated [`STATUS-1.7.0.md`](STATUS-1.7.0.md) /
[`STATUS-1.7.1.md`](STATUS-1.7.1.md), and the raw captures under
[`evidence-1.7.0/`](evidence-1.7.0/README.md) / [`evidence-1.7.1/`](evidence-1.7.1/README.md). None of
the repros depend on this repository's application code. Each repro directory contains a `run.sh`,
the fixtures it needs, and captured `transcript.txt` (1.6.7) / `transcript-1.7.0.txt` /
`transcript-1.7.1.txt` files (plus crash logs where relevant). The CLI surface is captured in
[`cli-surface-1.7.0.txt`](cli-surface-1.7.0.txt) and [`cli-surface-1.7.1.txt`](cli-surface-1.7.1.txt)
(identical); the 1.7.0/1.7.1 release notes, published 2026-10-20, in
[`release-notes-1.7.x.txt`](release-notes-1.7.x.txt).

A plain-language version of every defect, written in Simplified Technical English, is in
[`DEFECTS-STE.md`](DEFECTS-STE.md). The 1.7 documentation was re-read in full against these findings
on 2026-10-21: [`DOC-REVIEW-1.7.md`](DOC-REVIEW-1.7.md) (BUG-9 has a documented workaround, BUG-10 is
narrower, FR-3/FR-4 are largely closed).

## Bug reports

| Report | One-liner | Repro | 1.7.0 | 1.7.1 |
|---|---|---|---|---|
| [BUG-1](BUG-1-apply-noop-loop.md) | `apply` loops forever on a transitive-only dependency, reporting success while changing 0 files | [`repros/01`](../../repros/01-apply-noop-loop) | **Largely fixed** — refuses with a blocker summary (exit 50); 0-file "success" survives under `--accept-no-alignment` | Unchanged |
| [BUG-2a](BUG-2a-recipe-bundle-missing-rewrite-java-dependencies.md) | Boot-4 recipes reference `ModuleHasDependency` but the assembled coordinates omit `rewrite-java-dependencies` | [`repros/02`](../../repros/02-missing-recipe-bundle) | Unchanged | Unchanged (exit 30 now) |
| [BUG-2b](BUG-2b-apply-hijacks-project-rewrite-plugin.md) | On multi-module projects, `apply` runs the project's own rewrite-maven-plugin execution with Advisor's `-Drewrite.*` overrides — and dies there | [`repros/02`](../../repros/02-missing-recipe-bundle) | **Worse** → BUG-7 | Unchanged (hangs) |
| [BUG-3](BUG-3-duplicate-slug-inconsistent-loading.md) | Duplicate-slug mappings: `build-config` accepts, `upgrade-plan` rejects generically, `mapping create` crashes; root cause only in the crash log | [`repros/03`](../../repros/03-dup-slug-inconsistent-loading) | Unchanged | Unchanged |
| [BUG-4](BUG-4-mapping-create-empty-slug-hidden-file.md) | `mapping create` writes a hidden `.json` for empty slugs; silently clobbers; no `-o/--output` | [`repros/04`](../../repros/04-empty-slug-hidden-file) | Unchanged | Unchanged (Kafka 4.4.x row) |
| [BUG-5](BUG-5-resolution-ignores-project-repositories.md) | Coordinate resolution ignores the pom's `<repositories>` and misblames credentials | [`repros/05`](../../repros/05-resolution-ignores-repositories) | Unchanged (`mapping update` too) | Unchanged |
| [BUG-6](BUG-6-empty-mapping-silently-skipped.md) | An empty `{}` custom mapping is skipped with no warning naming the file | [`repros/06`](../../repros/06-empty-mapping-silent-skip) | Unchanged | Unchanged |
| [BUG-7](BUG-7-hijacked-project-plugin-hangs-recursive-descriptor-scan.md) | **New in 1.7.0:** the hijacked project plugin execution hangs at the first step in a recursive recipe-descriptor classpath scan (recipes 1.7.6) | [`repros/02/run-1.7.0-hang.sh`](../../repros/02-missing-recipe-bundle/run-1.7.0-hang.sh) | New | Unchanged (killed at 612 s, depth 36) |
| [BUG-8](BUG-8-forced-boot-41-step-pins-starters-parent-stays.md) | **New in 1.7.0:** with a `spring-boot` override mapping that lacks 4.1.x, the forced `4.0.x → 4.1.x` step pins every `spring-boot-starter-*` to 4.1.1 and leaves the parent at 4.0.8 instead of refusing (mixed generations) | real project, [`evidence-1.7.0/C-pass2-pom-changes.diff`](evidence-1.7.0/C-pass2-pom-changes.diff) | New | Not re-triggered (override unwired; 3.4.5 → 4.1.1 in one step, no pins) |
| [BUG-9](BUG-9-single-unmapped-transitive-hides-whole-plan.md) | **New in 1.7.0:** one unmapped transitive dependency silently removes every other project from the plan (exit 10, only a warning names it) | real project, [`evidence-1.7.0/A-raw-plan-7mappings.log`](evidence-1.7.0/A-raw-plan-7mappings.log) | New | **Unchanged — contradicts the 1.7.0 release note**; JSON `excludedProjects` names the hidden projects |
| [BUG-10](BUG-10-ignore-all-restrictions-empty-plan-exit-0.md) | **New in the 1.7.1 verification:** with every blocker ignored through `.advisor.yml` `upgrade.ignore`, the plan is empty, the console says only "No upgrade plan available", exit **0**, and the JSON report says `SUCCEEDED` with eight blocker-less `blockedUpgrades` | real project, [`evidence-1.7.1/C-ignore-probe-3.log`](evidence-1.7.1/C-ignore-probe-3.log) | — | New |

## Feature requests

| Report | One-liner | Demo | 1.7.0 | 1.7.1 |
|---|---|---|---|---|
| [FR-1](FR-1-first-party-kafka-confluent-mappings.md) | Ship first-party Apache Kafka + Confluent Platform family mappings (reference implementations included) | [`repros/07`](../../repros/07-no-first-party-kafka-mappings) | Still needed; catalog has none (`mapping search`), Kafka-4/Confluent-8 modules had to be hand-added | Still needed (1.7.1 adds Azure mappings only) |
| [FR-2](FR-2-family-aware-mapping-create-union-merge.md) | Family-aware `mapping create` + union-merge for same-slug mappings | [`repros/08`](../../repros/08-slug-collapse-family) | Still needed | Still needed |
| [FR-3](FR-3-machine-readable-plan-output.md) | `--format=json` for the upgrade plan | — | Partial: `patch apply` writes a JSON report; exit codes 10/50 | **Largely addressed** — `upgrade-plan.json` + exit-code table are documented (existed on 1.7.0 already) |
| [FR-4](FR-4-declarative-mapping-wiring.md) | Declarative mapping config instead of ordered env vars | — | Still needed | Still needed; `.advisor.yml` now exists (`upgrade.ignore`) |

## What changed vs. the earlier combined write-ups

These reports supersede parts of [`advisor-improvements.md`](../advisor-improvements.md)
and [`advisor-support-ticket.md`](../advisor-support-ticket.md), with two significant
re-scopings established while building the isolated repros (2026-08-20):

1. **The §4.10 "broken recipe bundle" wall is narrower than previously reported.** Clean
   Boot 3.4.5 apps — single- or multi-module, with tests, JUnit 4, even `spring-kafka` —
   upgrade to Boot 4.1.x **successfully** via repeated `apply --accept-no-alignment`. The
   `ModuleHasDependency` failure is triggered by the project's own `rewrite-maven-plugin`
   declaration, via two vectors: its plugin `<dependencies>` downgrade
   `rewrite-java-dependencies` to a pre-class version through Maven mediation (this hits
   Advisor's **own** invocation, any module layout — possible only because Advisor never
   pins the module, BUG-2a), and on multi-module projects the prepended
   `process-test-classes` phase additionally runs the project's phase-bound execution with
   Advisor's `-Drewrite.*` overrides (BUG-2b). Each is independently fixable, and together
   they fully explain the failure previously believed universal and non-workaroundable.
   **Workaround (verified on a copy of this repo):** remove/guard the entire plugin
   declaration — the full 19-project forced apply then completes with real file changes;
   neutralizing the execution alone is not sufficient.
2. **BUG-1's no-op loop is fully reproducible in a 13-line-dependency pom** — it needs
   nothing from the original project beyond one transitive dependency with no version
   literal to rewrite.

And on **2026-10-12 (Advisor 1.7.0)**: BUG-1's default-path loop is gone, the BUG-2b hijack
turned into a hang (BUG-7), and two new planning/apply defects appeared (BUG-8, BUG-9). The
committed `advisor` branch also turned out not to compile from a clean checkout (spring-kafka
4.0 `@RetryableTopic backOff`), which the 1.6.7 build check had missed — fixed in the same commit.

And on **2026-10-21 (Advisor 1.7.1)**: nothing moved — every row above reproduces as on 1.7.0. The
release notes for 1.7.0/1.7.1 appeared on 2026-10-20 and revealed `upgrade-plan.json` (FR-3 largely
closed, overlooked in the 1.7.0 write-up), documented the opposite of BUG-9, and introduced the ignore
mechanism whose end state is BUG-10.
