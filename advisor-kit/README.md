# Advisor upgrade kit

This kit upgrades a Maven Spring Boot repository with Spring Application Advisor.
It contains the upgrade script, the curated mapping files, and the necessary
workarounds. Copy this directory into your repository, or run it from a shared
location.

## Kit map

| Path                                      | Purpose                                    | Owner          |
|-------------------------------------------|--------------------------------------------|----------------|
| `advisor-upgrade.sh`                       | Runs the whole upgrade                     | Framework team |
| `mappings/*.json`                          | Curated upgrade mappings                   | Framework team |
| `mappings/order.txt`                       | Wiring manifest (env-var order)            | Framework team |
| `snippets/rewrite-plugin-profile-guard.xml`| Pom template for the required plugin guard | Framework team |
| `docs/operating-model.md`                  | How Advisor works                          | Framework team |
| `docs/framework-team.md`                   | Framework team tasks and rules             | Framework team |
| `docs/release-cadence.md`                  | How releases, mappings, git, Maven align   | Framework team |
| `docs/app-team-runbook.md`                 | Step-by-step upgrade procedure             | Framework team |
| `docs/known-issues.md`                     | Known Advisor defects and workarounds      | Framework team |

## Prerequisites

| Requirement                            | Check                                        |
|----------------------------------------|----------------------------------------------|
| Advisor CLI 1.6.x on PATH              | `advisor --version`                          |
| Java 17+ and a Maven build             | `./mvnw -v` in the target repo               |
| Spring Enterprise Maven credentials    | `<server>` entry in `~/.m2/settings.xml`     |
| Clean git worktree, on a branch        | `git status`                                 |

The kit never contains credentials. Each user configures `~/.m2/settings.xml`.

## Quickstart

1. Guard the `rewrite-maven-plugin` in the target pom.
   Use `snippets/rewrite-plugin-profile-guard.xml`. This step is mandatory.
2. Run a dry run and read the plan:
   `./advisor-kit/advisor-upgrade.sh --dry-run <repo-dir>`
3. Run the upgrade:
   `./advisor-kit/advisor-upgrade.sh --force -y <repo-dir>`
4. Fix the remaining compile breaks.
   Follow `docs/app-team-runbook.md`, step 4.

## Read next

| Document                   | Read it when                                    |
|----------------------------|-------------------------------------------------|
| `docs/app-team-runbook.md` | You upgrade an application                      |
| `docs/operating-model.md`  | You want to understand what Advisor does        |
| `docs/framework-team.md`   | You maintain this kit or curate mappings        |
| `docs/release-cadence.md`  | You plan framework releases and kit distribution |
| `docs/known-issues.md`     | The upgrade fails or behaves in a strange way   |
