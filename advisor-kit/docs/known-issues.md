# Known Advisor issues

All issues below were verified on Advisor 1.6.7, re-verified on **1.7.0** (recipes 1.7.6)
on 2026-10-12 and again on **1.7.1** on 2026-10-21 (same recipes, same CLI; 1.7.1 only adds Azure
SDK mappings). Every row below is **unchanged on 1.7.1** unless the "1.7.0" column says otherwise;
BUG-10 is the one addition. Each row tells you what to do
without further reading. Full repros and reports live in the source repo
(`docs/reports/` and `repros/` — source repo only; this page stands alone).

## Defects

| Id    | Symptom                                                                 | Kit workaround                                                       | 1.7.0 |
|-------|-------------------------------------------------------------------------|----------------------------------------------------------------------|-------|
| BUG-1 | Plain `apply` reports success but changes no files. The plan repeats.   | The script's `--force` mode applies with `--accept-no-alignment` until convergence. | Mostly fixed: plain `get`/`apply` now refuse with a blocker list and exit 50 instead of looping. `--force` is still the only mode that applies. |
| BUG-2a| Apply fails: "Recipe class not found: ...ModuleHasDependency". Advisor does not pin `rewrite-java-dependencies`. | Guard the project's rewrite plugin (see BUG-2b).                    | Unchanged (recipes 1.7.6). |
| BUG-2b| The project's own `rewrite-maven-plugin` declaration (its `<dependencies>` and `<executions>`) hijacks Advisor's apply run. | Move the declaration into a profile. Template: `snippets/rewrite-plugin-profile-guard.xml`. The script's preflight enforces this. | **Worse: the hijacked execution now hangs at the first step (BUG-7).** The guard is mandatory. |
| BUG-3 | Two custom mappings with the same slug: `build-config get` accepts them, `upgrade-plan get` rejects them, `mapping create` crashes ("Some projects were already defined"). | Keep one file per slug. The script detects collisions and skips the second file. | Unchanged. |
| BUG-4 | `mapping create` for some coordinates writes a hidden `.json` file with an empty slug. | The script filters invalid outputs and never wires them.            | Unchanged. |
| BUG-5 | Mapping resolution ignores the repositories in your pom. Confluent artifacts fail with a misleading credentials error. | Curated `confluent-platform.json` carries the `repositoryUrl` field. | Unchanged; `mapping update` has the same blind spot. |
| BUG-6 | A wired empty mapping makes every Advisor command fail: "One of the custom mappings provided is empty". | The script validates each mapping before it wires it. If you hit it: delete the empty file. | Unchanged. |
| BUG-7 | Forced apply never finishes: the Maven child spins at 100 % per core for an hour (recursive recipe-descriptor scan inside the project's own `rewrite-maven-plugin` execution, recipes 1.7.6). | Guard the project's rewrite plugin (BUG-2b template). The script refuses to run while it is unguarded. Kill a stuck run with `pkill -f runNoFork`. | New in 1.7.0 |
| BUG-8 | After the forced "spring-boot 4.0.x → 4.1.x" step the parent stays 4.0.8 but every Spring Boot starter gets an explicit `<version>4.1.1</version>` pin (mixed Boot generations; the build still passes). Trigger: a custom `override` mapping for `spring-boot` that does not define 4.1.x (the kit's 1.6.x-era `spring-boot-jackson3.json`). | The kit no longer wires `spring-boot-jackson3.json` (commented out in `mappings/order.txt`). Do not wire your own `spring-boot` override on 1.7.x. If a run already produced pins: review `git diff`, remove the pins, move the parent (runbook step 4). | New in 1.7.0 |
| BUG-9 | `upgrade-plan get` shows two projects and "No upgrade plan available" (exit 10) on a Boot 3.4.5 app; the 20+ real projects are hidden because one transitive dependency (here `org.apache.zookeeper:zookeeper`) has no mapping, and nothing says so. | The kit ships `zookeeper.json`; the script's self-heal now also reads the six-space-indented "transitive dependencies" list and creates mappings for it. | New in 1.7.0 |
| BUG-10 | You ignore every blocker with `.advisor.yml` (`upgrade.ignore`, new in 1.7.0) and `upgrade-plan get` prints "No upgrade plan available" with **exit 0**; `target/.advisor/upgrade-plan.json` says `SUCCEEDED` with an empty `steps` list. What still holds the plan is the dependency-alignment state, which nothing reports. | Do not key CI on exit 0 alone — check that `steps` in `upgrade-plan.json` is non-empty. The kit's `--force` mode (`--accept-no-alignment`) still produces the step. Ignore keys: the slug whose *mapping declares* the restriction (e.g. `jackson` for jackson-annotations, but `apache-commons-io` for the commons-lang restriction). | New in 1.7.1 verification |

## Feature requests

| Id   | Request                                                            | Kit stopgap                                             |
|------|--------------------------------------------------------------------|---------------------------------------------------------|
| FR-1 | Ship first-party mappings for Apache Kafka, Confluent, and Avro. The catalog has none (checked with `advisor mapping search`). | The kit ships curated `apache-kafka.json`, `confluent-platform.json`, `avro.json`. |
| FR-2 | Make `mapping create` family-aware. Per-coordinate runs collapse onto one slug and cannot be co-wired. | The framework team curates family files by hand.        |
| FR-3 | Add machine-readable plan output (`--format=json`).                | Largely delivered in 1.7.0 as `target/.advisor/upgrade-plan.json` (documented 2026-10-20). The script now reads it (steps, blocked upgrades, unmapped coordinates, exit status) and only parses the console text on Advisor 1.6.x or without `python3`. |
| FR-4 | Replace the ordered env vars with a declarative mapping config file. | `mappings/order.txt` is the kit's own manifest; the script derives the env vars. |

## Version note

Advisor upgrades one Spring generation per pass and can stop below the
newest generation (verified on 1.6.7 and 1.7.0: a plan that targets 4.1.x
converges at 4.0.x; on 1.7.0 the 4.1 step pins the starters instead — BUG-8).
Re-run the kit after the next Advisor/recipes release to continue. On 1.7.1 with
the override unwired, the reference app went Boot 3.4.5 → **4.1.1** in a single
forced step (the parent moved, no pins).

1.7.0 also changed the plan output and added exit codes **10** (unmapped
dependencies present) and **50** (plan refused, blocker summary); the full table
(get 0/10/50/60/70, apply also 30 = recipe failure, 40 = PR failure) is in the
1.7 release notes published 2026-10-20. Every `get`/`apply` also writes
`target/.advisor/upgrade-plan.json` (plan, blockers, *excluded projects*, exit
code) — read it rather than the console. The script
prints both exit codes. New commands: `mapping search --slug <slug>` (downloads a catalog
mapping), `mapping update` (appends newly released versions to existing mapping
files; leaves the curated files untouched), `recipe show <name>` (declarative
recipes only) and `patch apply` (pins transitive dependencies to their latest
patch versions via `<dependencyManagement>` and writes
`.advisor/patch-upgrade-report.json`; review before adopting).
