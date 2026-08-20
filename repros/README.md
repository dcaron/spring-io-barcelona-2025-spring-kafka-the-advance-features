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

## Running

Each directory has a `run.sh` (run it from anywhere; it cd's itself). Requirements:
`advisor` 1.6.x on PATH, Maven, network; repros 01/02 additionally need working Spring
Enterprise subscription credentials in `~/.m2/settings.xml` (recipes download during
apply). Every directory contains the captured `transcript.txt` from the verification runs
of 2026-08-20 (Advisor 1.6.7, recipes 1.7.5, Maven 3.9.16), plus `error-stacktrace.log`
where a crash log is the evidence.

Caution: `02` runs `advisor upgrade-plan apply`, whose first (successful) step rewrites
the repro's own poms (Boot parent 3.4.5 → 3.5.x) before the second step fails — reset the
parent `<version>` back to `3.4.5` (or `git checkout -- repros/02-missing-recipe-bundle`)
after a run. `01` also runs `apply` but never changes a file — that is the bug it
demonstrates. All state Advisor creates (`target/`, `.advisor/`) is deleted at the start
of each `run.sh`.
