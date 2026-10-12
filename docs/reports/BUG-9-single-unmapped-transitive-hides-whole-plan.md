# BUG-9 — one unmapped transitive dependency silently hides the whole upgrade plan (1.7.0)

| | |
|---|---|
| Type | Defect (UX / planning) |
| Advisor | **1.7.0** (not present on 1.6.7) |
| Verified | 2026-10-12, original repo (guarded Boot 3.4.5 worktree, 7 curated mappings wired) |
| Evidence | [`evidence-1.7.0/A-raw-plan-7mappings.log`](evidence-1.7.0/A-raw-plan-7mappings.log), [`A-raw-plan-ana.log`](evidence-1.7.0/A-raw-plan-ana.log) → [`A-raw-plan-8mappings.log`](evidence-1.7.0/A-raw-plan-8mappings.log) |

## Summary

With the same seven custom mappings that produced a 20-project plan on 1.6.7, 1.7.0 reports:

```
Projects discovered:
	- javafaker: 1.0.x (no upgrades available)
	- micrometer-context-propagation: 1.1.x → 1.2.x
No upgrade plan available.
⚠️  Warnings:
- There are no upgrade mappings configured for these transitive dependencies:
      - org.apache.zookeeper:zookeeper
exit 10
```

`--accept-no-alignment` gives a one-item plan (`micrometer-context-propagation`). Nothing says
that spring-boot, spring-kafka, kafka, confluent, jackson … were **dropped because of
zookeeper**. After wiring a generated `zookeeper.json` (one `mapping create`), the same command
discovers **26 projects** and offers the full 23-item forced plan.

On 1.6.7 the unmapped zookeeper was listed in the blocked section but the other projects still
appeared in "Projects discovered" and in the forced plan.

## Why it matters

- The default output looks like "this project is nearly up to date" on a Boot 3.4.5 app. Our
  kit script, which keys on the plan text, printed *"No further upgrades to apply — the
  repository is upgraded as far as the available mappings allow."*
- The only hint is a warning whose list is indented differently (six spaces) from the
  "Add upgrade mappings for these dependencies:" list (tab), which also broke our parser.
- Exit code 10 is returned both here and when a plan *is* produced but unmapped transitives
  exist (`A-raw-plan-ana.log`), so the code alone does not distinguish "plan hidden" from
  "plan with caveats".

## Expected

- Keep discovering/planning the projects that *can* be planned, as 1.6.7 did, and say which
  projects were excluded **because of** which unmapped dependency.
- Or at least print the dependency in the "blocker projects" summary (exit 50 style) rather
  than only in a warning, and use one indentation for all coordinate lists.
