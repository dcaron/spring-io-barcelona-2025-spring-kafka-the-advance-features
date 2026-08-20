# BUG-1 — `upgrade-plan apply` loops forever on a transitive-only dependency

| | |
|---|---|
| Type | Defect |
| Advisor | 1.6.7 (first seen 1.6.5) |
| Verified | 2026-08-20, isolated minimal project |
| Repro | [`repros/01-apply-noop-loop/`](../../repros/01-apply-noop-loop) (13-line dependency section + 2 mapping fixtures) |

## Summary

When the bottom-of-tree project selected by `upgrade-plan apply` is a dependency the
project never declares directly (purely transitive), the apply step has no version
literal to rewrite. Advisor still selects it, reports **"👍 Successfully applied
upgrade"**, changes **zero files**, re-plans, selects the same project again — forever.
The upgrade never reaches any project that would actually change files.

## Minimal reproduction

A one-pom project whose only dependency is `commons-validator:commons-validator:1.7`,
which pulls `commons-beanutils:commons-beanutils:1.9.4` **transitively** (never declared
anywhere). Custom mappings for both projects are wired (fixtures in `mappings/`; Advisor's
catalog does not configure them). Then:

```console
$ ./run.sh          # upgrade-plan get, then apply three times
=== upgrade-plan apply — run 1 ===
Projects to upgrade:
    * commons-beanutils from 1.9.x to 1.11.x
👍 Successfully applied upgrade.
>>> run 1 changed NO project files (checksums identical)
=== upgrade-plan apply — run 2 ===        # identical
=== upgrade-plan apply — run 3 ===        # identical
```

Three consecutive runs each select `commons-beanutils 1.9.x → 1.11.x`, each report
success, each change nothing (`transcript.txt` has the full capture). In the original
project this same loop (six consecutive identical applies) permanently starved the real
targets — `spring-boot`, `spring-kafka`, `jackson` — which sit above the stuck leaf.

## Expected

- An apply that changes no files and leaves the selected project's resolved version
  unchanged must not be reported as success and re-selected; treat the project as
  non-actionable and advance, or stop with a clear message.
- Better: never surface a transitive-only / BOM-managed artifact as a standalone apply
  step — upgrade it together with the direct dependency that pulls it in.

## Notes

`--force` and `--squash=N` do not help (they still resolve "the first step" to the same
no-op). `--accept-no-alignment` escapes the loop but has its own defects (BUG-2a/2b).
