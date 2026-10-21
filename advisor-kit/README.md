# Advisor upgrade kit

This kit upgrades a Maven Spring Boot repository with Spring Application Advisor.
It contains the upgrade script, a snapshot of the curated mapping files, and the
necessary workarounds. Copy this directory into your repository, or run it from
a shared location.

**Status: interim.** The mapping files are managed centrally, in the central
mappings repository owned by the framework team. This kit bundles a snapshot of
that repository at each kit release. The target model is that apps and CI fetch
mappings from the central repository directly, and later from Advisor itself
(FR-1/FR-4 in `docs/known-issues.md`). See `docs/release-cadence.md`.

## Kit map

| Path                                      | Purpose                                    | Owner          |
|-------------------------------------------|--------------------------------------------|----------------|
| `advisor-upgrade.sh`                       | Runs the whole upgrade                     | Framework team |
| `mappings/*.json`                          | Snapshot of the central mappings repo      | Framework team |
| `mappings/order.txt`                       | Wiring manifest (env-var order)            | Framework team |
| `snippets/rewrite-plugin-profile-guard.xml`| Pom template for the required plugin guard | Framework team |
| `docs/operating-model.md`                  | How Advisor works                          | Framework team |
| `docs/framework-team.md`                   | Framework team tasks and rules             | Framework team |
| `docs/release-cadence.md`                  | How releases, mappings, git, Maven align   | Framework team |
| `docs/app-team-runbook.md`                 | Step-by-step upgrade procedure             | Framework team |
| `docs/ci-pipeline.md`                      | How app teams run the kit from CI          | Framework team |
| `docs/known-issues.md`                     | Known Advisor defects and workarounds      | Framework team |

## Prerequisites

| Requirement                            | Check                                        |
|----------------------------------------|----------------------------------------------|
| Advisor CLI 1.7.x on PATH (1.6.x works) | `advisor --version`                          |
| Java 17+ and a Maven build             | `./mvnw -v` in the target repo               |
| Spring Enterprise Maven credentials    | `<server>` entry in `~/.m2/settings.xml`     |
| Clean git worktree, on a branch        | `git status`                                 |
| `python3` (any 3.x) — reads Advisor's `target/.advisor/upgrade-plan.json`; without it the script parses the console text | `python3 --version` |

The kit never contains credentials. Each user configures `~/.m2/settings.xml`.

## Quickstart

1. Guard the `rewrite-maven-plugin` in the target pom.
   Use `snippets/rewrite-plugin-profile-guard.xml`. This step is mandatory.
2. Run a dry run and read the plan:
   `./advisor-kit/advisor-upgrade.sh --dry-run <repo-dir>`
3. Run the upgrade:
   `./advisor-kit/advisor-upgrade.sh --force -y <repo-dir>`
4. Fix the remaining compile breaks and review the version pins.
   Follow `docs/app-team-runbook.md`, step 4.

Kit verified on Advisor **1.7.0** (2026-10-12) and **1.7.1** (2026-10-21), recipes 1.7.6; see `docs/known-issues.md`.

## Read next

| Document                   | Read it when                                    |
|----------------------------|-------------------------------------------------|
| `docs/app-team-runbook.md` | You upgrade an application                      |
| `docs/ci-pipeline.md`      | You automate the upgrade in your CI pipeline    |
| `docs/operating-model.md`  | You want to understand what Advisor does        |
| `docs/framework-team.md`   | You maintain this kit or curate mappings        |
| `docs/release-cadence.md`  | You plan framework releases and kit distribution |
| `docs/known-issues.md`     | The upgrade fails or behaves in a strange way   |
