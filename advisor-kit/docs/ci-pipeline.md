# App teams — run the kit from CI

The upgrade is not a build step. It is a job that writes code and opens a
pull request. Developers review the PR, fix the remaining compile breaks,
and merge. Run the job on a schedule or on demand — never on every commit.

## What the CI runner needs

| Requirement                     | How                                                      |
|---------------------------------|----------------------------------------------------------|
| Advisor CLI 1.6.x               | Bake it into the runner image, or install it in the job  |
| Java + the repo's Maven wrapper | Same image as your normal build                          |
| Maven credentials               | Write `~/.m2/settings.xml` from a CI secret in the job   |
| Git push + PR rights            | A bot identity with a token, scoped to the app repo      |
| The kit                         | Committed in the repo, or fetched at a pinned kit tag. The kit tag pins the mappings snapshot too (interim model, see `release-cadence.md`) |

Never commit credentials. Never print `settings.xml` to the job log.

## Diagram F — the two jobs

```
  schedule (weekly)                     manual trigger / after a kit tag
        |                                          |
        v                                          v
  +------------------+                   +----------------------------+
  | JOB 1: plan      |                   | JOB 2: upgrade             |
  | dry run, no edits|                   | new branch                 |
  +------------------+                   | run --force -y --no-build  |
        |                                | commit + push              |
        v                                | open PR                    |
  plan as job artifact                   +----------------------------+
  "upgrades available: yes/no"                     |
                                                   v
                                     normal PR pipeline builds + tests
                                                   |
                                                   v
                                     developer fixes breaks on the PR
                                     (runbook step 4), then merges
```

## Job 1 — plan (scheduled, read-only signal)

```sh
printf '%s' "$MAVEN_SETTINGS_XML" > ~/.m2/settings.xml
./advisor-kit/advisor-upgrade.sh --dry-run . | tee advisor-plan.txt
```

Publish `advisor-plan.txt` as a job artifact. Alert the team when the plan
shows "Projects discovered". Note: the dry run can add mapping files under
`.advisor/mappings/`; this job discards them (it does not push).

## Job 2 — upgrade (manual, writes a branch)

```sh
printf '%s' "$MAVEN_SETTINGS_XML" > ~/.m2/settings.xml
git switch -c advisor-upgrade-$(date +%Y%m%d)
./advisor-kit/advisor-upgrade.sh --force -y --no-build .
git add -A ':!target'
git commit -m "Advisor upgrade (automated; needs manual fixes)"
git push -u origin HEAD
# open the PR with your platform's CLI (gh pr create / glab mr create)
```

Use `--no-build` in the job. The PR pipeline compiles anyway, and compile
breaks are expected output, not job failures. The PR is a starting point:
a developer finishes it with runbook step 4.

## Exit codes and failure handling

| Exit | Meaning                          | Job action                             |
|------|----------------------------------|----------------------------------------|
| 0    | Converged, or nothing to do      | Push only when files changed           |
| 1    | Preflight or apply failed        | Fail the job; upload `.advisor/errors/`|
| 2    | BUG-1 no-op (plain apply)        | Should not occur with `--force`        |

On exit 1, upload the newest `.advisor/errors/*.log` as a job artifact and
attach it when you report the problem to the framework team.

## Rules

1. Pin the kit version in CI (a git tag or a committed copy). Do not track
   a moving branch.
2. One upgrade branch per run. Delete stale upgrade branches after merge.
3. Cache `~/.m2/repository` like your normal build. Do not cache
   `~/.m2/settings.xml`.
4. Commit `.advisor/mappings/` changes with the upgrade. They are part of
   the reproducible result (see `release-cadence.md`, rule 5).
