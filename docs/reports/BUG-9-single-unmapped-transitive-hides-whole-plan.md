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

## Status on Advisor 1.7.1 (re-verified 2026-10-21, recipes 1.7.6)

**Unchanged — and now contradicted by Broadcom's own 1.7.0 release note.** The note published on
2026-10-20 says: *"When a transitive dependency has no upgrade mapping, `advisor upgrade-plan get` and
`advisor upgrade-plan apply` calculate the plan and print a warning. Previously, the missing mapping
blocked the plan. Only missing mappings for your direct dependencies block the plan."*
(`release-notes-1.7.x.txt`; the docs page *Missing mappings for transitive dependencies* repeats it).
On the guarded Boot 3.4.5 worktree with the same seven mappings (zookeeper unwired) 1.7.1 still
discovers **two** projects, prints *"No upgrade plan available"* and exits **10**; the only trace is
the warning naming `org.apache.zookeeper:zookeeper`. Wiring `zookeeper.json` again brings back 26
projects and the 24-item forced plan ([`evidence-1.7.1/A-bug9-probe-no-zookeeper.log`](evidence-1.7.1/A-bug9-probe-no-zookeeper.log)
vs [`A-raw-plan.log`](evidence-1.7.1/A-raw-plan.log)).

The new JSON report makes the exclusion explicit, which the console never does: its
`excludedProjects` entry lists the 22 projects dropped *because of* zookeeper
(`"exclusion": {"apache-commons-io": ["confluent", "testcontainers", "spring-kafka", "spring-boot", …]}`)
while `projects` has 2 entries and `executionMetadata` is `{"exitCode": 10, "status": "BLOCKED"}`
([`A-bug9-probe-upgrade-plan.json`](evidence-1.7.1/A-bug9-probe-upgrade-plan.json)). So the engine
knows exactly which projects it hid; the documented behaviour (plan + warning) is simply not what the
CLI does for this dependency graph. Worth attaching to the ticket: the doc quote, the two logs and the
JSON.

## Documentation re-read (2026-10-21, techdocs 1.7 pages dated 2026-10-20)

**Severity reduced — a documented flag works around it; the defect is now "default behaviour and
console differ from the documentation".** The CLI reference says for exit 10: *"Missing mappings — one
or more artifacts lack upgrade mappings. Use `--force` to generate a partial plan anyway"*, and for
`-f/--force` on `upgrade-plan get`: *"Continues to calculate the upgrade plan when dependencies have no
upgrade mappings. The command lists those dependencies as warnings instead of stopping with an error."*
Verified on a fresh Boot 3.4.5 worktree with `zookeeper.json` unwired
([`evidence-1.7.1/A-bug9-probe-force-flag.log`](evidence-1.7.1/A-bug9-probe-force-flag.log),
[`…-combos.log`](evidence-1.7.1/A-bug9-probe-force-flag-combos.log)):

| Command | Projects | Plan | Exit | JSON `excludedProjects` |
|---|---|---|---|---|
| `get` | 2 | none | 10 | zookeeper |
| `get --accept-no-alignment` | 2 | 1 item | 10 | zookeeper |
| `get -f` | 25 | none, 4 real blockers | 50 | empty |
| `get -f --accept-no-alignment` (either order) | 25 | the full 24-item step | 0 | empty |
| `get -f --squash-all` | 25 | none, 4 blockers | 50 | empty |

So `-f` restores exactly the state that wiring the zookeeper mapping produced. Two discrepancies
remain and are what to report: (1) the release note and the *"Missing mappings for transitive
dependencies"* section say the **default** run calculates the plan and only warns for an unmapped
transitive — it does not; (2) with `-f` the unmapped coordinate is not *"listed as a warning"* either:
it disappears from the console and from `excludedProjects` entirely. The `--help` text for `-f`
(*"Force execution of full Upgrade Plan, including intermediate dependencies"*) does not match the
reference. The kit now re-plans and applies with `-f` when unmapped dependencies remain after
self-healing (`advisor-kit/advisor-upgrade.sh`, `UNMAPPED_FORCE`).
