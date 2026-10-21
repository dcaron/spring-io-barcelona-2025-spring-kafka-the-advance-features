# FR-3 — Machine-readable output for `upgrade-plan get` (`--format=json`)

| | |
|---|---|
| Type | Feature request |
| Advisor | 1.6.7 (flag surface unchanged since 1.6.4) |
| Demonstration | any plan transcript, e.g. [`repros/07-no-first-party-kafka-mappings/transcript.txt`](../../repros/07-no-first-party-kafka-mappings/transcript.txt) |

## The gap

The upgrade plan is emitted only as tab-indented prose mixed with progress spinners:

```
Projects discovered:
	- spring-kafka: 3.3.x → 4.1.x
Please request your administrator to configure the projects of the following dependencies:

	- org.apache.kafka:kafka_2.13
		uses:
			- apache-commons-collections
		blocking upgrades for:
			- spring-boot
	...
Upgrade Plan for your Dependencies:
	- Step 1:
		* Upgrade commons-beanutils from 1.9.x to 1.11.x
```

Tooling that drives Advisor (CI gates, self-healing wrappers like this repo's
`advisor-upgrade.sh`, dashboards) must scrape this text — e.g. "exactly one leading tab,
then `group:artifact`, end of line" to extract blocked coordinates — which silently breaks
whenever the wording or indentation changes (the 1.6.7 output added `uses:`/`blocking
upgrades for:` sub-blocks, which is exactly such a change).

## The ask

`advisor upgrade-plan get --format=json` (and ideally `build-config get` too) exposing as
structured data:

- discovered projects with current/target generations,
- plan steps (ordered) with per-step project upgrades,
- blocked dependencies, each with its owning/using projects and the projects it blocks,
- warnings (version conflicts) and errors.

The data plainly exists — it is all in the prose. A stable JSON contract would remove the
scraping layer entirely and make failures (BUG-1's loop, BUG-3's rejection) detectable by
scripts.

## Status on Advisor 1.7.0 (re-verified 2026-10-12, recipes 1.7.6)

**Partially addressed elsewhere.** `upgrade-plan get` still has no `--format=json`, but the new
`advisor patch apply` writes `.advisor/patch-upgrade-report.json` (per pom → scope → coordinate /
oldVersion / newVersion) — the first machine-readable output in the CLI
(`evidence-1.7.0/P-patch-upgrade-report.json`). The same for the upgrade plan would close this
request. New in 1.7.0: distinct exit codes **10** (unmapped dependencies present) and **50** (plan
refused, blocker summary) — useful for scripting, but 10 is returned both with and without a plan.

## Status on Advisor 1.7.1 (re-verified 2026-10-21, recipes 1.7.6)

**Largely addressed — correction to the 1.7.0 verdict.** The 1.7.0 release notes (published
2026-10-20) document `target/.advisor/upgrade-plan.json`, written by **both** `upgrade-plan get` and
`apply` (`steps`, `projects`, `excludedProjects`, `blockedUpgrades`, `executionMetadata{exitCode,status}`,
`scmMetadata`, `pullRequestInfo`), plus `target/.advisor/patch-upgrade.json` for `patch apply`, and a
full exit-code table (get: 0/10/50/60/70; apply: 0/10/30/40/50/60/70). The file already existed on
1.7.0 — it is sitting in the `adv170-A-guarded` worktree's `target/.advisor/` — and was overlooked on
2026-10-12 because the CLI never mentions it. Verified on 1.7.1: every `get` in `evidence-1.7.1/`
produced one ([`C-upgrade-plan.json`](evidence-1.7.1/C-upgrade-plan.json),
[`A-bug9-probe-upgrade-plan.json`](evidence-1.7.1/A-bug9-probe-upgrade-plan.json)). Two caveats worth
feeding back: `executionMetadata.exitCode` is **0 / SUCCEEDED** for a plan that was computed only under
`--accept-no-alignment`, and also for the no-plan outcome produced with every restriction ignored
(see BUG-10 in `STATUS-1.7.1.md`); and the console still never points at the file. The kit script
should switch from parsing the plan text to reading this JSON.
