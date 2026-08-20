# Advisor reports — one issue per file, one verified repro each

Every report below was re-verified on **Advisor 1.6.7** on **2026-08-20** against an
**isolated minimal reproduction** under [`repros/`](../../repros) — none of them depend on
this repository's application code. Each repro directory contains a `run.sh`, the fixtures
it needs, and a captured `transcript.txt` (plus `error-stacktrace.log` where relevant).

## Bug reports

| Report | One-liner | Repro |
|---|---|---|
| [BUG-1](BUG-1-apply-noop-loop.md) | `apply` loops forever on a transitive-only dependency, reporting success while changing 0 files | [`repros/01`](../../repros/01-apply-noop-loop) |
| [BUG-2a](BUG-2a-recipe-bundle-missing-rewrite-java-dependencies.md) | Boot-4 recipes reference `ModuleHasDependency` but the assembled coordinates omit `rewrite-java-dependencies` | [`repros/02`](../../repros/02-missing-recipe-bundle) |
| [BUG-2b](BUG-2b-apply-hijacks-project-rewrite-plugin.md) | On multi-module projects, `apply` runs the project's own rewrite-maven-plugin execution with Advisor's `-Drewrite.*` overrides — and dies there | [`repros/02`](../../repros/02-missing-recipe-bundle) |
| [BUG-3](BUG-3-duplicate-slug-inconsistent-loading.md) | Duplicate-slug mappings: `build-config` accepts, `upgrade-plan` rejects generically, `mapping create` crashes; root cause only in the crash log | [`repros/03`](../../repros/03-dup-slug-inconsistent-loading) |
| [BUG-4](BUG-4-mapping-create-empty-slug-hidden-file.md) | `mapping create` writes a hidden `.json` for empty slugs; silently clobbers; no `-o/--output` | [`repros/04`](../../repros/04-empty-slug-hidden-file) |
| [BUG-5](BUG-5-resolution-ignores-project-repositories.md) | Coordinate resolution ignores the pom's `<repositories>` and misblames credentials | [`repros/05`](../../repros/05-resolution-ignores-repositories) |
| [BUG-6](BUG-6-empty-mapping-silently-skipped.md) | An empty `{}` custom mapping is skipped with no warning naming the file | [`repros/06`](../../repros/06-empty-mapping-silent-skip) |

## Feature requests

| Report | One-liner | Demo |
|---|---|---|
| [FR-1](FR-1-first-party-kafka-confluent-mappings.md) | Ship first-party Apache Kafka + Confluent Platform family mappings (reference implementations included) | [`repros/07`](../../repros/07-no-first-party-kafka-mappings) |
| [FR-2](FR-2-family-aware-mapping-create-union-merge.md) | Family-aware `mapping create` + union-merge for same-slug mappings | [`repros/08`](../../repros/08-slug-collapse-family) |
| [FR-3](FR-3-machine-readable-plan-output.md) | `--format=json` for the upgrade plan | — |
| [FR-4](FR-4-declarative-mapping-wiring.md) | Declarative mapping config instead of ordered env vars | — |

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
