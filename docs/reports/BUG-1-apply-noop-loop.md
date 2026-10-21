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

## Status on Advisor 1.7.0 (re-verified 2026-10-12, recipes 1.7.6)

**Changed — largely fixed on the default path, no-op survives under `--accept-no-alignment`.**
`upgrade-plan get` on the same fixture now prints *"No upgrade plan available. … Here's a summary
of blocker projects and potential actions to take: commons-beanutils:1.9.x needs an upgrade or
migration defined in the upgrade mappings to upgrade apache-commons-collections > 3.2.x"* and exits
**50**; three `apply` runs print the same and change nothing — no more false *"Successfully
applied"*. `-f` and `--squash-all` do not change that. `get --accept-no-alignment` yields *Step 1:
apache-commons-collections 3.2→4.5 + commons-beanutils 1.9→1.11*; `apply --accept-no-alignment`
reports success in 50 s and still changes **0 files** (the transitive has no literal to rewrite),
so the forced path can still produce success-with-no-change steps (seen on the real project as
step 2 in `STATUS-1.7.0.md`, scenario C). Transcripts: `transcript-1.7.0.txt`,
`probe-force-squash-1.7.0.txt`.

## Status on Advisor 1.7.1 (re-verified 2026-10-21, recipes 1.7.6)

**Unchanged from 1.7.0.** Same fixture, same three runs: `get` and every `apply` print the blocker
summary (*commons-beanutils:1.9.x needs an upgrade or migration … apache-commons-collections > 3.2.x*),
exit **50**, 0 files changed; the normalized transcript differs from 1.7.0 only in timings
(`transcript-1.7.1.txt`). 1.7.1 is a mappings-only release (ten Azure SDK mappings, no CVE fixes —
`release-notes-1.7.x.txt`) and the CLI surface is byte-identical (`cli-surface-1.7.1.txt`).

## Note from the conflict-fixed run (2026-10-21)

On the `advisor` branch with every version conflict removed (`STATUS-1.7.1.md` §D), the JSON report's
two `blockedUpgrades` entries with **empty `blockerProjects`** are precisely this defect's shape:
`commons-validator 1.10.x → 1.11.x` (transitive-only) and `kafka 4.2.x → 4.3.x` (managed by the Boot
BOM, no literal in any pom). The docs describe such entries as *"needs a migration that the upgrade
mappings do not define"*; what they actually are is "nothing to rewrite in this repository". Reporting
them that way (and not as upgrades under *Projects discovered*) would close the last confusing output
of this defect.
