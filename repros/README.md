# Isolated minimal reproductions for the Advisor reports

One directory per issue; each is self-contained (own pom/fixtures, no dependence on this
repository's application code) and scripted. Reports live in
[`docs/reports/`](../docs/reports).

| Dir | Reproduces | Report(s) |
|---|---|---|
| `01-apply-noop-loop/` | `apply` selects transitive-only `commons-beanutils`, "success", 0 files changed, forever | BUG-1 |
| `02-missing-recipe-bundle/` | multi-module `apply --accept-no-alignment` dies at the project's own rewrite plugin: `Recipe class not found: …ModuleHasDependency` | BUG-2a, BUG-2b |
| `03-dup-slug-inconsistent-loading/` | same-slug mappings: build-config OK / upgrade-plan generic reject / mapping create crash with real cause | BUG-3 |
| `04-empty-slug-hidden-file/` | `mapping create` writes hidden `.advisor/mappings/.json` with `slug: ""` | BUG-4 |
| `05-resolution-ignores-repositories/` | pom-declared Confluent repo ignored; failure misblamed on credentials | BUG-5 |
| `06-empty-mapping-silent-skip/` | wired `{}` mapping silently dropped | BUG-6 |
| `07-no-first-party-kafka-mappings/` | ordinary spring-kafka app: 16 blocked coordinates, "request your administrator" | FR-1 |
| `08-slug-collapse-family/` | sibling `mapping create` runs → same slug `kafka`, cannot be co-wired | FR-2, BUG-3 |

## Re-verification on Advisor 1.7.0 (2026-10-12)

Every directory also has a `transcript-1.7.0.txt` (recipes 1.7.6), plus the 1.7.0 counterparts of
the crash logs / generated files (`*-1.7.0.*`). Per-issue verdicts are in each report's *"Status on
Advisor 1.7.0"* section and in [`docs/reports/STATUS-1.7.0.md`](../docs/reports/STATUS-1.7.0.md).
Headline: `03`–`06`, `08` unchanged; `07` same coordinates, new output format and exit code 10;
`01` no longer loops (blocker summary, exit 50); `02` now **hangs** at the first step —
run [`02-missing-recipe-bundle/run-1.7.0-hang.sh`](02-missing-recipe-bundle/run-1.7.0-hang.sh)
(bounded, default 600 s) instead of `run.sh` on 1.7.x. `01-apply-noop-loop/probe-force-squash-1.7.0.txt`
records the `-f` / `--squash-all` / `--accept-no-alignment` probes.

## Re-verification on Advisor 1.7.1 (2026-10-21)

Every directory also has a `transcript-1.7.1.txt` (Advisor 1.7.1, recipes 1.7.6 — unchanged) plus the
1.7.1 counterparts of the crash logs / generated files (`*-1.7.1.*`; `02` additionally has
`variants-1.7.1.txt` + `error-stacktrace-single-module-1.7.1.log` for the single-module BUG-2a variant).
Headline: **all eight are unchanged from 1.7.0** — the normalized transcripts differ only in timings,
timestamps and, for `04`, the newly released Kafka 4.4.x row. 1.7.1 is a mappings-only release (ten
Azure SDK mappings, no CVE fixes; its release notes are in
[`docs/reports/release-notes-1.7.x.txt`](../docs/reports/release-notes-1.7.x.txt)) and the CLI surface
is byte-identical to 1.7.0. `02`'s hang script was killed at the 600 s cap with the Maven child at
recursion depth 36 (BUG-7 stands); the single-module variant fails at the Boot-4 step exactly as before
(BUG-2a), now with exit code 30. Verdicts: [`docs/reports/STATUS-1.7.1.md`](../docs/reports/STATUS-1.7.1.md).

## Running

Each directory has a `run.sh` (run it from anywhere; it cd's itself). Requirements:
`advisor` 1.6.x or 1.7.x on PATH, Maven, network; repros 01/02 additionally need working Spring
Enterprise subscription credentials in `~/.m2/settings.xml` (recipes download during
apply). Every directory contains the captured `transcript.txt` from the verification runs
of 2026-08-20 (Advisor 1.6.7, recipes 1.7.5, Maven 3.9.16) and `transcript-1.7.0.txt` from 2026-10-12 (Advisor 1.7.0, recipes 1.7.6) / `transcript-1.7.1.txt` from 2026-10-21 (Advisor 1.7.1), plus `error-stacktrace.log`
where a crash log is the evidence.

Caution: `02` runs `advisor upgrade-plan apply`, whose first (successful) step rewrites
the repro's own poms (Boot parent 3.4.5 → 3.5.x) before the second step fails — reset the
parent `<version>` back to `3.4.5` (or `git checkout -- repros/02-missing-recipe-bundle`)
after a run. `01` also runs `apply` but never changes a file — that is the bug it
demonstrates. All state Advisor creates (`target/`, `.advisor/`) is deleted at the start
of each `run.sh`.
