# BUG-3 — Duplicate-slug custom mappings: accepted by `build-config`, rejected by `upgrade-plan`, crash `mapping create`

| | |
|---|---|
| Type | Defect |
| Advisor | 1.6.7 |
| Verified | 2026-08-20, fully synthetic fixtures (no Kafka involved) |
| Repro | [`repros/03-dup-slug-inconsistent-loading/`](../../repros/03-dup-slug-inconsistent-loading) (two 25-line mapping fixtures + minimal pom) |

## Summary

Two custom mappings that share a slug are handled three different ways by three commands,
and the only accurate error text is hidden in a crash log:

| Command | Behavior with two `slug: "demo"` mappings wired |
|---|---|
| `build-config get` | **Succeeds** (duplicate silently tolerated) |
| `upgrade-plan get` | **Fails** on the second file with a generic message: *"Failed to load an additional upgrade mapping from '…/demo-b.json': Failed to load the mapping source. Please verify the source configuration."* |
| `mapping create -c=<covered coordinate>` | **Crashes** ("open a support ticket") — the error log finally names the real cause |

From `error-stacktrace.log` (via `MappingsLoader.buildReport`, `MappingsLoader.java:90`):

```
MappingSourceLoadException: Failed to load mapping source '.../demo-b.json':
  Error merging mapping source ...
Caused by: java.lang.IllegalArgumentException: Some projects were already defined: [demo]
```

So the 1.6.5-era `RaiseErrorOnDuplicatesCoordinatesMerger` behavior is still the root
cause; 1.6.7 merely gave `build-config get` a tolerant load path while `upgrade-plan get`
and `mapping create` still use the strict one.

## Reproduction (`run.sh`, full capture in `transcript.txt`)

`mappings/demo-a.json` (slug `demo`, coordinate `org.apache.commons:commons-lang3`) and
`mappings/demo-b.json` (slug `demo`, coordinate `org.apache.commons:commons-text`), wired
via `SPRING_ADVISOR_MAPPING_CUSTOM_{0,1}_FILEPATH`, against a two-dependency pom:

```console
$ advisor build-config get     # ✅ succeeds
$ advisor upgrade-plan get     # 💔 fails on demo-b.json, generic message
$ advisor mapping create -c=org.apache.commons:commons-lang3
                               # 💔 crash; log: "Some projects were already defined: [demo]"
```

Cross-slug overlap on the same *coordinate* is, by contrast, tolerated end-to-end.

## Why it matters

`mapping create` itself emits same-slug files for sibling modules of one family (see
FR-2 / `repros/08`), so Advisor's own generated output trips this rejection. A wiring that
survives `build-config get` then dies at plan time with a message that doesn't say *why*.

## Expected

- All commands should apply the **same** mapping-loading rules.
- The user-facing error should state the actual cause and both files: *"duplicate slug
  'demo': already defined by demo-a.json"* — the information demonstrably exists (it's in
  the crash log).
- Preferably: union-merge same-slug mappings instead of rejecting (see FR-2).

## Status on Advisor 1.7.0 (re-verified 2026-10-12, recipes 1.7.6)

**Unchanged** — identical three-way behaviour (`build-config get` accepts, `upgrade-plan get`
rejects the second file generically, `mapping create` crashes with *"Some projects were already
defined: [demo]"* only in the log). `transcript-1.7.0.txt`, `error-stacktrace-1.7.0.log`.

## Status on Advisor 1.7.1 (re-verified 2026-10-21, recipes 1.7.6)

**Unchanged** — transcript identical to 1.7.0 modulo timings; `mapping create` still crashes with
*"Some projects were already defined: [demo]"* visible only in the error log
(`transcript-1.7.1.txt`, `error-stacktrace-1.7.1.log`).

## Status on Advisor 1.7.2 (re-verified 2026-11-16, recipes 1.7.7)

**Partially fixed — the message, not the inconsistency.** `upgrade-plan get` now rejects the second
same-slug file with a specific, actionable message: *"Slug(s) demo are already defined by another mapping
source. To replace the existing definition, set 'merge-strategy' to 'OVERRIDE' for this custom mapping
source. To keep both definitions, rename the slug in this file and verify that they do not share
coordinates."* (1.7.1: *"Failed to load the mapping source. Please verify the source configuration."*).
The crash in `mapping create` is unchanged apart from a typed exception
(`com.vmware.tanzu.spring.advisor.exceptions.DuplicateMappingSlugException: Some projects were already
defined: [demo]`, still only in the error log), and `build-config get` still accepts the pair silently
(`transcript-1.7.2.txt`, `error-stacktrace-1.7.2.log`). Following the new hint works: with
`SPRING_ADVISOR_MAPPING_CUSTOM_1_MERGE_STRATEGY=override` the plan is computed (`demo 1.10.x → 1.12.x`)
and `mapping create` no longer crashes (`probe-override-1.7.2.txt`). Remaining ask: the same validation
in all three commands, and the root cause on the console for `mapping create`.
