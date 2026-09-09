# Known Advisor issues

All issues below were verified on Advisor 1.6.7. Each row tells you what to do
without further reading. Full repros and reports live in the source repo
(`docs/reports/` and `repros/` — source repo only; this page stands alone).

## Defects

| Id    | Symptom                                                                 | Kit workaround                                                       | Status   |
|-------|-------------------------------------------------------------------------|----------------------------------------------------------------------|----------|
| BUG-1 | Plain `apply` reports success but changes no files. The plan repeats.   | The script's `--force` mode applies with `--accept-no-alignment` until convergence. | Reported |
| BUG-2a| Apply fails: "Recipe class not found: ...ModuleHasDependency". Advisor does not pin `rewrite-java-dependencies`. | Guard the project's rewrite plugin (see BUG-2b).                    | Reported |
| BUG-2b| The project's own `rewrite-maven-plugin` declaration (its `<dependencies>` and `<executions>`) hijacks Advisor's apply run. | Move the declaration into a profile. Template: `snippets/rewrite-plugin-profile-guard.xml`. The script's preflight enforces this. | Reported |
| BUG-3 | Two custom mappings with the same slug: `build-config get` accepts them, `upgrade-plan get` rejects them, `mapping create` crashes ("Some projects were already defined"). | Keep one file per slug. The script detects collisions and skips the second file. | Reported |
| BUG-4 | `mapping create` for some coordinates writes a hidden `.json` file with an empty slug. | The script filters invalid outputs and never wires them.            | Reported |
| BUG-5 | Mapping resolution ignores the repositories in your pom. Confluent artifacts fail with a misleading credentials error. | Curated `confluent-platform.json` carries the `repositoryUrl` field. | Reported |
| BUG-6 | A wired empty mapping makes every Advisor command fail: "One of the custom mappings provided is empty". | The script validates each mapping before it wires it. If you hit it: delete the empty file. | Reported |

## Feature requests

| Id   | Request                                                            | Kit stopgap                                             |
|------|--------------------------------------------------------------------|---------------------------------------------------------|
| FR-1 | Ship first-party mappings for Apache Kafka, Confluent, and Avro. The catalog has none (checked with `advisor mapping search`). | The kit ships curated `apache-kafka.json`, `confluent-platform.json`, `avro.json`. |
| FR-2 | Make `mapping create` family-aware. Per-coordinate runs collapse onto one slug and cannot be co-wired. | The framework team curates family files by hand.        |
| FR-3 | Add machine-readable plan output (`--format=json`).                | The script parses the human-readable plan text.         |
| FR-4 | Replace the ordered env vars with a declarative mapping config file. | `mappings/order.txt` is the kit's own manifest; the script derives the env vars. |

## Version note

Advisor upgrades one Spring generation per pass and can stop below the
newest generation (verified: a plan that targets 4.1.x converges at 4.0.x).
Re-run the kit after the next Advisor/recipes release to continue.
