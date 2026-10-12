# Advisor 1.7.0 — re-verification of every finding (2026-10-12)

| | |
|---|---|
| Advisor | **1.7.0** (`/usr/local/bin/advisor`), commercial recipes **1.7.6** (bundle: `java-recipes, rewrite-apache, rewrite-migrate-java, rewrite-spring, spring-boot-2/3/4-upgrade-recipes`), `rewrite-maven-plugin:6.44.0:runNoFork` |
| Previous | 1.6.7, recipes 1.7.5, same plugin (state tagged `advisor-1.6.7-verified`) |
| Release notes | none published for 1.7 on techdocs at verification time (newest: 1.6.7, 2026-08-18); the CLI is the changelog — [`cli-surface-1.7.0.txt`](cli-surface-1.7.0.txt) |
| Evidence | [`evidence-1.7.0/`](evidence-1.7.0/README.md) (Phase 2 captures), `repros/*/…-1.7.0.*` (Phase 1 transcripts) |
| Method | Phase 1: the 8 isolated repros + 5 new-CLI probes. Phase 2: the real project from Boot 3.4.5 (guarded worktree `ec8552a`, unguarded `049fdd6`) and from the committed 4.0.8 state (`advisor` HEAD), driven by the kit script; plus `patch apply`. Phase 3: this write-up, docs, kit and mapping updates. |

## 1. Per-issue verdicts

| Issue | 1.6.7 | 1.7.0 | Verdict |
|---|---|---|---|
| BUG-1 apply no-op loop | infinite *"Successfully applied"*, 0 files | `get`/`apply`: *"No upgrade plan available … summary of blocker projects"*, exit **50**, nothing applied; `-f`/`--squash-all` same; `--accept-no-alignment` applies, still 0 files on the transitive-only fixture | **Largely fixed** (default path honest; forced path still 0-file "successes") |
| BUG-2a missing `rewrite-java-dependencies` | `ModuleHasDependency` not found at Boot-4 step | identical with recipes 1.7.6 (single-module variant) | Unchanged |
| BUG-2b project plugin hijack | fails at Boot-4 step | **hangs at step 1** (recursive descriptor scan) | **Worse** → [BUG-7](BUG-7-hijacked-project-plugin-hangs-recursive-descriptor-scan.md) |
| BUG-3 duplicate slug | accept / generic reject / crash | identical | Unchanged |
| BUG-4 empty-slug hidden file | `.json`, slug `""` | identical (richer requirements table) | Unchanged |
| BUG-5 pom repositories ignored | misblames credentials | identical; `mapping update` shares the blind spot | Unchanged |
| BUG-6 empty mapping silent | no warning | identical | Unchanged |
| FR-1 first-party Kafka/Confluent | none | none (`mapping search --slug` for 6 slugs → *"No project found"*); Kafka-4/Confluent-8 added 7 unmapped modules | Still needed |
| FR-2 family-aware create | slug collapse | identical; `mapping update` adds versions, not coordinates | Still needed |
| FR-3 machine-readable plan | none | `patch apply` writes `.advisor/patch-upgrade-report.json`; exit codes 10/50 | Partial |
| FR-4 declarative wiring | env vars | env vars; `--from-yml` is only the CI opt-in | Still needed |
| **new** [BUG-7](BUG-7-hijacked-project-plugin-hangs-recursive-descriptor-scan.md) | — | hijacked execution recurses in `UpgradeJackson_2_3_ApiOnly.getRecipeList → Environment.activateRecipes → classpath scan`, >62 min, 7 cores, 4.4 GB | New |
| **new** [BUG-8](BUG-8-forced-boot-41-step-pins-starters-parent-stays.md) | — | with this repo's `spring-boot-jackson3.json:override` mapping (generations 3.5.x/4.0.x only) the forced `spring-boot 4.0.x → 4.1.x` step pins 41 starters to 4.1.1 and leaves the parent at 4.0.8; without it the parent moves to 4.1.1 cleanly | New (triggered by an incomplete override mapping; Advisor should refuse, not pin) |
| **new** [BUG-9](BUG-9-single-unmapped-transitive-hides-whole-plan.md) | — | one unmapped transitive (zookeeper) hides 24 projects; only a warning names it; exit 10 | New |

## 2. Output and CLI changes that affect tooling

- `upgrade-plan get` now exits **10** when any dependency lacks a mapping (with or without a plan) and
  **50** when it refuses to plan and prints *"Here's a summary of blocker projects and potential actions
  to take"*. 1.6.7 always exited 0.
- Unmapped coordinates come in two lists with different indentation: *"Add upgrade mappings for these
  dependencies:"* (direct, tab) and *"There are no upgrade mappings configured for these transitive
  dependencies:"* (six spaces). The 1.6.7 *"Please request your administrator…"* block is gone.
- New warnings: *"There is an error in <project>, several versions are used simultaneously"* (junit 4+5,
  jackson 2.17/2.18, commons-lang, commons-io on this repo), *"Incomplete <slug> mappings: version X does
  not exist"*.
- `apply` regenerates the build configuration on every run (*"Build configuration file does not exist!
  Generating it..."*).
- New commands/flags: `mapping search --slug`, `mapping update`, `recipe show`, `patch apply`;
  `apply --include-modules/--exclude-modules/--squash-all/--build-tools-latest/--after-upgrade-cmd/-f`.
  No 1.6.7 `--help` capture exists, so "new in 1.7.0" vs "unnoticed in 1.6.7" cannot be told apart for
  the flags; `recipe show` and `mapping update` are listed in the 1.6.7 release notes.

## 3. Real-project scenarios

### A — guarded Boot 3.4.5 worktree, kit script (`evidence-1.7.0/A-*`)

1. Plain plan with the 7 curated mappings of the 1.6.7 run: 2 projects discovered, *"No upgrade plan
   available"*, exit 10; the only unmapped coordinate is `org.apache.zookeeper:zookeeper` (BUG-9).
   `--accept-no-alignment`: a one-item plan.
2. + generated `zookeeper.json`: **26 projects** discovered; plain plan refused with 3 blockers
   (commons-beanutils, confluent, javafaker need mapping entries), exit 50; forced plan = one 23-item
   step (spring-boot 3.4→4.1, kafka 3.8→4.3, confluent 7.9→8.3, jackson 2.17→3.2, junit 4→6 …).
3. `--force -y`: **one step, 4 m 56 s**, 23 files, all app modules **3.4.5 → 4.0.8** (same convergence
   as 1.6.7). New in the recipes: `org.springframework.boot.autoconfigure.kafka →
   org.springframework.boot.kafka.autoconfigure` imports/javadoc (7 files), `spring-boot-starter-web →
   -webmvc`, `spring-kafka → spring-boot-starter-kafka(-test)`, `spring-boot-starter-opentelemetry` added,
   `confluent.kafka.version 7.9.1 → 8.3.2`, OTLP tracing properties and health-probe default migrated in
   `application.yml`. **But also** `<version>4.1.1</version>` on 18 starter dependencies under the 4.0.8
   parent (BUG-8).
4. Build check failed: 5 compile sites in 4 modules — `KafkaProperties.buildConsumerProperties(SslBundles)`
   ×4, `PropertyMapper.alwaysApplyingWhenNonNull()`; plus `buildProperties(null)`. These are the same
   API fixes the 1.6.7 run needed (1.6.7 additionally needed all the import moves by hand). After them
   the reactor still fails in `non-blocking-retries-example`: `@RetryableTopic(backoff = @Backoff)` with
   `org.springframework.retry.annotation.Backoff` → spring-kafka 4.0 wants `backOff = @BackOff` from
   `org.springframework.kafka.annotation`. **The committed `advisor` branch (1.6.7 result) has the same
   error when built from clean** — its build check had passed on stale classes. Fixed on the branch
   in this commit.
5. Pass 2 after the fixes: no plan — the 7 Kafka-4/Confluent-8 coordinates are now the unmapped
   transitives (BUG-9 again).

### B — unguarded Boot 3.4.5 worktree (`evidence-1.7.0/B-*`)

- Unwired plan (repro 07 at scale): 18 unmapped coordinates (3 direct, 15 transitive), exit 10.
- `--force` with `--skip-guard-check`: **hangs** exactly like repro 02 — Advisor's `6.44.0:runNoFork`
  Maven child at recursion depth 35 after 11 min, 784 % CPU, 4.5 GB; killed; poms untouched (BUG-7).

### C — `advisor` branch HEAD, Boot 4.0.8 (`evidence-1.7.0/C-*`)

1. Plan: *"No upgrade plan available"*, exit 10; 7 unmapped transitives new since Kafka 4 / Confluent 8
   (`kafka-share-coordinator`, `kafka-coordinator-common`, `kafka-transaction-coordinator`,
   `kafka-test-common-runtime`, `kafka-test-common-internal-api`, `io.confluent:kafka-avro-types`,
   `kafka-schema-types`). Added to the curated `apache-kafka.json` / `confluent-platform.json`.
2. With them: 24 projects, plain plan refused (11 blockers, exit 50); forced plan = 14-item step incl.
   spring-boot 4.0→4.1, spring-kafka 4.0→4.1, kafka 4.1→4.3, jackson 2.17→3.2.
3. `--force -y` pass 1: apply **aborted before any rewrite** — Advisor's `mvn process-test-classes …`
   compiles each module first and `non-blocking-retries-example` does not compile (see A.4). Advisor
   needs a project that compiles from clean.
4. After the `backOff` fix: step 1 (2 m 17 s) "Successfully applied", build check passed —
   **+53 lines, 0 deletions: 41 × `<version>4.1.1</version>` on `spring-boot-starter-*`, micrometer
   pins; parent stays 4.0.8** (BUG-8). Resolved tree: starters 4.1.1 on Boot core modules 4.0.8. Step 2:
   same list, "Successfully applied", **0 files** → kit declares convergence at 4.0.8 + pins.
5. BUG-8 scoping: a minimal single-module Boot 3.4.5 app with no project plugin and no custom mappings
   goes 3.4.5 → 3.5.17 → 4.0.8 → **4.1.1 parent, no pins** in three forced steps
   (`evidence-1.7.0/BUG8-minimal-repro.log`). On this project the trigger is the
   `spring-boot-jackson3.json:override` mapping (1.6.x-era, generations 3.5.x/4.0.x only): the same
   forced step **without it** moves all six parents `4.0.8 → 4.1.1`, pins nothing, and the reactor
   builds with Boot 4.1.1 / spring-kafka 4.1.1 / Jackson 3.1.5 (`BUG8-scoping-no-override.log`,
   `BUG8-no-override-pom-changes.diff`). The override is now unwired in `order.txt` (repo and kit).

### `patch apply` (`evidence-1.7.0/P-*`)

8 m 25 s, exit 0, 7 poms, +555 lines: bumps `avro.version` 1.12.0 → 1.12.2 and adds a
`<dependencyManagement>` block per module pinning ~25 **transitive** artifacts to their latest patch
(jackson 2.21.5→2.21.7, tools.jackson 3.1.5→3.1.7, tomcat-embed 11.0.24→11.0.27, slf4j 2.0.18→2.0.20,
confluent 8.3.1→8.3.2, …). Writes `.advisor/patch-upgrade-report.json`. Leaves Boot and Spring Kafka
alone. The pins override the Boot BOM (`jackson-core 2.22.3` in `events`), so review before adopting.

## 4. What changed in this repository because of 1.7.0

- `blocking-vs-nonblocking-retries/non-blocking-retries-example`: `@RetryableTopic(backOff = @BackOff(...))`
  (spring-kafka 4.0 API) — the branch compiles from clean again.
- `.advisor/mappings/` and `advisor-kit/mappings/`: `apache-kafka.json` +5 Kafka-4 coordinates,
  `confluent-platform.json` +2 Confluent-8 coordinates, new `zookeeper.json`, `order.txt` wires it and
  **unwires `spring-boot-jackson3.json:override`** (BUG-8 trigger on 1.7.x; Jackson 3 arrives anyway).
- `advisor-kit/advisor-upgrade.sh`: version gate 1.7.x; blocked-coordinate parser reads both 1.7.0
  lists; plan detection keys on *"Upgrade Plan for your Dependencies"* / *"No upgrade plan available"*
  instead of arrows alone; `--force` mode plans with `--accept-no-alignment`; exit codes 10/50 are
  explained. Root `advisor-upgrade.sh`: version gate only (historical copy).
- `advisor-kit/docs/*`: known issues (BUG-7/8/9, 1.7.0 column), runbook (clean-compile precondition,
  `backOff` fix, pin review, new troubleshooting rows), README, CI pipeline, release cadence.
- `docs/advisor-improvements.md` §1d, `docs/advisor-support-ticket.md` (1.7.0 block, Defects 4–5),
  `docs/kafka-mappings-ticket.md` (1.7.0 status), every report's *"Status on Advisor 1.7.0"*,
  `repros/README.md`, `repros/02-missing-recipe-bundle/run-1.7.0-hang.sh`.

## 5. Open points

- The 1.7.0 forced step **without the override mapping** takes the branch from 4.0.8 to **Boot 4.1.1**
  (six parents, one property, builds from clean) — applied to the `advisor` branch as its own commit so
  it can be reverted independently. Worktrees `../adv170-A-guarded`, `-B-unguarded`, `-C`, `-P` keep
  the raw run results.
- File BUG-7/8/9 with Broadcom (ticket draft updated); re-check techdocs for 1.7 release notes.
