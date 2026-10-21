# Advisor 1.7.1 — re-verification of every finding (2026-10-21)

| | |
|---|---|
| Advisor | **1.7.1** (`/usr/local/bin/advisor`, binary dated 2026-10-19), commercial recipes **1.7.6** (unchanged), `rewrite-maven-plugin:6.44.0:runNoFork` (unchanged) |
| Previous | 1.7.0, recipes 1.7.6 — [`STATUS-1.7.0.md`](STATUS-1.7.0.md) |
| Release notes | **Now published** (2026-10-20) for 1.7.0 *and* 1.7.1 — text in [`release-notes-1.7.x.txt`](release-notes-1.7.x.txt). 1.7.1 = *"ten Azure SDK for Java mappings, each as its own mapping"* + *"No CVEs patched in this release"*. Nothing else. |
| CLI surface | [`cli-surface-1.7.1.txt`](cli-surface-1.7.1.txt) is **byte-identical** to 1.7.0 for every command (the only diff is `build-config publish`, which the 1.7.0 capture had not included) |
| Evidence | [`evidence-1.7.1/`](evidence-1.7.1/README.md) (real project), `repros/*/…-1.7.1.*` (isolated repros) |
| Method | Same three phases as 1.7.0: the 8 isolated repros (+ the single-module BUG-2a variant, + catalog probes); the real project from Boot 3.4.5 (guarded worktree `ec8552a`, current curated mappings) and from `advisor` HEAD (Boot 4.1.1, `5fbf01a`), driven by the kit script; `patch apply`; plus probes of the 1.7.0 features the release notes revealed (`.advisor.yml` `upgrade.ignore`, `upgrade-plan.json`, exit codes). |

**Headline.** 1.7.1 changes nothing for this project: all nine defects and four feature requests
reproduce exactly as on 1.7.0. What *did* change is our knowledge, because the 1.7.0 release notes
finally appeared: they document behaviour that BUG-9 contradicts, a JSON plan report that already
existed on 1.7.0 (FR-3 largely addressed — our 1.7.0 write-up missed it), and an ignore mechanism
whose end state is a new defect (BUG-10).

## 1. Per-issue verdicts

| Issue | 1.7.0 | 1.7.1 | Verdict |
|---|---|---|---|
| BUG-1 apply no-op loop | blocker summary, exit 50; forced path 0-file "success" | identical (`repros/01/transcript-1.7.1.txt`); real project: forced steps on A pass 2 and on C report success with **0 files** | Unchanged |
| BUG-2a missing `rewrite-java-dependencies` | `ModuleHasDependency` at Boot-4 step | identical in the single-module variant; failed apply now exits **30** (`repros/02/variants-1.7.1.txt`) | Unchanged |
| BUG-2b project plugin hijack | hangs (BUG-7) | hangs | Unchanged |
| BUG-3 duplicate slug | three-way behaviour | identical | Unchanged |
| BUG-4 empty-slug hidden file | `.json`, slug `""` | identical; table now reaches Kafka **4.4.x** | Unchanged |
| BUG-5 pom repositories ignored | misblames credentials | identical | Unchanged |
| BUG-6 empty mapping silent | no warning | identical | Unchanged |
| BUG-7 hijack hangs | depth 35, >62 min | depth 33 at 2 min, 36 from 3 min on, 4.3 GB, killed at the 612 s cap, pom untouched | Unchanged |
| BUG-8 forced 4.1 step pins starters | triggered by the (now unwired) override | not re-triggered: with the override unwired A goes 3.4.5 → **4.1.1** in one step, no pins | Not re-tested with the trigger |
| BUG-9 unmapped transitive hides plan | zookeeper hides 24 projects, exit 10 | **identical — and the 1.7.0 release note says the opposite** (*"Only missing mappings for your direct dependencies block the plan"*); the JSON report's `excludedProjects` even lists the 22 hidden projects | Unchanged, now doc-contradicted |
| **new** [BUG-10](BUG-10-ignore-all-restrictions-empty-plan-exit-0.md) | — | `.advisor.yml` `upgrade.ignore` with every blocker ignored → *"No upgrade plan available"*, **exit 0**, JSON `SUCCEEDED` with `steps: []` and 8 `blockedUpgrades` that have no `blockerProjects` | New |
| FR-1 first-party Kafka/Confluent | none | none; 1.7.1's new mappings are Azure only; `mapping search` finds no kafka/confluent/avro/zookeeper slugs | Still needed |
| FR-2 family-aware create | slug collapse | identical; Azure note confirms the catalog has no family concept | Still needed |
| FR-3 machine-readable plan | "partial: patch report only" | **Largely addressed, correction:** `target/.advisor/upgrade-plan.json` is written by `get` and `apply` (documented; it was already there on 1.7.0 in `../adv170-A-guarded/target/.advisor/`), `target/.advisor/patch-upgrade.json` by `patch apply`, full exit-code table published | Mostly closed; caveats in the report |
| FR-4 declarative wiring | env vars | env vars; but `.advisor.yml` now exists (`upgrade.ignore`, blocked versions) — the natural home | Still needed |

## 2. What the release notes changed in our picture

- `upgrade-plan get`/`apply` exit codes are documented: get 0/10/50/60/70, apply adds 30 (recipe
  execution failure) and 40 (PR creation). Our kit's "10 = unmapped, 50 = blocked" reading was right.
- `target/.advisor/upgrade-plan.json` (`steps`, `projects`, `excludedProjects`, `blockedUpgrades`,
  `executionMetadata`, `scmMetadata`) exists on every `get`/`apply`. The console never mentions it. The
  kit should read it instead of parsing text; `excludedProjects` is exactly the BUG-9 diagnostic the
  console lacks.
- *"When a transitive dependency has no upgrade mapping … calculate the plan and print a warning"* —
  not what happens here (BUG-9 probe: [`evidence-1.7.1/A-bug9-probe-no-zookeeper.log`](evidence-1.7.1/A-bug9-probe-no-zookeeper.log)).
- `.advisor.yml` `upgrade.ignore.<slug>.dependencies/reason`: the key is the slug whose *mapping
  declares* the restriction, which is the first-named slug for `lastSupportedVersion`-type blockers
  (`jackson` → jackson-annotations) but the *second*-named one for `nextSupportingVersion`-type
  blockers (`apache-commons-io` → apache-commons-lang). The working file for this project is
  [`evidence-1.7.1/C-ignore-probe-3.advisor.yml`](evidence-1.7.1/C-ignore-probe-3.advisor.yml) — and
  its result is BUG-10.
- Also documented, not probed: blocked versions (org/repo level), mapping-referenced skills unpacked
  into `.claude/skills`, conditional recipes (Boot 4.0 mapping picks Jackson 2 vs 3 recipes), Spring
  Integration recipes, `patch apply --skip-transitive-deps`.

## 3. Real-project scenarios

### A — guarded Boot 3.4.5 worktree, current curated mappings (`evidence-1.7.1/A-*`)

Mappings as committed on `advisor` HEAD: 8 wired (`zookeeper.json` in, `spring-boot-jackson3.json:override`
**out**). This differs from the 1.7.0 A run, which still had the override wired — so A's outcome
changes two variables at once (Advisor 1.7.1 *and* no override).

1. Plain plan: 26 projects discovered, refused with 4 blockers (commons-validator ×2, confluent,
   javafaker), exit 50. Forced plan: one 24-item step (1.7.0: 23; `apache-commons-io/collections`,
   `xmlunit` now have catalog mappings).
2. `--force -y`: **one step, 4 m 13 s, Boot 3.4.5 → 4.1.1** in all six app modules (1.7.0 with the
   override: 4.0.8 + 18 starter pins). Same recipe output as 1.7.0 otherwise: Kafka autoconfigure
   package move in imports and javadoc (7 Java files, imports only), `confluent.kafka.version`
   7.9.1 → 8.3.2, OTLP property migration and the `probes.enabled: false` + TODO in every
   `application.yml`, starter renames.
3. Build check: the **same five compile sites** as 1.7.0 — `KafkaProperties.buildConsumerProperties(SslBundles)`
   ×3, `buildProperties(null)`, `PropertyMapper.alwaysApplyingWhenNonNull()` — plus the still-unmigrated
   `@RetryableTopic(backoff = @Backoff)` (spring-kafka 4.x wants `backOff = @BackOff`). After those
   edits the reactor installs green with Boot 4.1.1.
4. Pass 2: 24 projects, forced 8-item step (jackson 2.17 → 3.2, jackson-annotations, kafka 4.2 → 4.3,
   commons-io/collections/compress/validator, xmlunit) — *"Successfully applied"*, **0 files**; the
   kit stops. The Kafka-4/Confluent-8 coordinates added on 2026-10-12 keep BUG-9 away this time.

### BUG-9 probe (`evidence-1.7.1/A-bug9-probe-*`)

Same worktree, `zookeeper.json` unwired: 2 projects discovered, no plan, exit 10, one warning line.
`upgrade-plan.json`: `executionMetadata {10, BLOCKED}`, `excludedProjects` = zookeeper with the 22
projects it excludes. Unchanged from 1.7.0 and contrary to the release note.

### C — `advisor` HEAD, Boot 4.1.1 (`evidence-1.7.1/C-*`)

1. Plan: 24 projects, refused with 7 blockers (exit 50); forced plan = the same 8-item step as A pass 2.
2. `--force -y`: *"Successfully applied"*, **0 files changed**, JSON `{0, SUCCEEDED}` — the forced-path
   no-op of BUG-1, unchanged. The branch is as far as the mappings take it: Boot 4.1.1, spring-kafka
   4.1.1, Jackson 3.1.5 via the Boot BOM.
3. `upgrade.ignore` probes 1–3 and the flag matrix: see BUG-10.

### `patch apply` (`evidence-1.7.1/P-*`)

8 m 14 s, exit 0, 7 poms, +975 / −7 lines: `avro.version` 1.12.0 → 1.12.2 and a `<dependencyManagement>`
block per module pinning 51 distinct transitive artifacts (278 pin lines): kafka-clients 4.2.1 → 4.2.2,
tools.jackson 3.1.5 → 3.1.8, jackson 2.21.5 → 2.21.8, tomcat-embed 11.0.24 → 11.0.27, slf4j 2.0.18 →
2.0.20, confluent 8.3.1 → 8.3.2, httpclient5/httpcore5, byte-buddy, swagger-annotations … Writes both
the documented `target/.advisor/patch-upgrade.json` (56 entries) and the 1.7.0-era
`.advisor/patch-upgrade-report.json`. Same caveat as before: the pins override the Boot BOM — review
before adopting, or use `--skip-transitive-deps`.

## 4. What changed in this repository because of 1.7.1

- No source or mapping changes: the `advisor` branch stays at Boot 4.1.1 (nothing applied).
- New: this file, [`BUG-10`](BUG-10-ignore-all-restrictions-empty-plan-exit-0.md), [`evidence-1.7.1/`](evidence-1.7.1/README.md),
  [`cli-surface-1.7.1.txt`](cli-surface-1.7.1.txt), [`release-notes-1.7.x.txt`](release-notes-1.7.x.txt),
  `repros/*/…-1.7.1.*`; every report has a *"Status on Advisor 1.7.1"* section; `STATUS-1.7.0.md` and
  `docs/advisor-improvements.md` §1d carry a dated correction about the release notes and the JSON report.
- `advisor-kit/advisor-upgrade.sh`: version gate text (verified on 1.7.0 and 1.7.1); `advisor-kit/README.md`,
  `docs/known-issues.md`, `docs/app-team-runbook.md`, `docs/release-cadence.md` updated.

## 5. Documentation re-read (same day)

After this status was written, all 73 pages of the 1.7 documentation were read against the findings
([`DOC-REVIEW-1.7.md`](DOC-REVIEW-1.7.md)). Net effect: BUG-9 has a documented workaround (`-f`), BUG-10
is narrower (the blockers are this project's own version conflicts; exit 0 follows a documented rule),
BUG-5 is now provable with `-d`, FR-4 is largely closed by folder/Git/Artifactory mapping sources, and
the kit re-plans with `-f`. The verdict table in §1 is superseded for BUG-9 and BUG-10 by that file.

## 5a. Open points

- File BUG-7/8/9/10 with Broadcom; for BUG-9 attach the release-note quote and the JSON
  `excludedProjects` capture. Ticket draft: `docs/advisor-support-ticket.md`.
- Kit: ~~read `target/.advisor/upgrade-plan.json` instead of parsing console text~~ (done 2026-10-21:
  `plan_json` in `advisor-upgrade.sh`, text parser kept as the 1.6.x fallback; it also flags the
  BUG-10 state — exit 0, no step, blocked upgrades pending); ship a
  `.advisor.yml` template with the ignore keys for this project (knowing it ends in BUG-10 unless
  `--accept-no-alignment` is also used); keep `spring-boot-jackson3.json` unwired.
- Worktrees `../adv171-A-guarded` (Boot 4.1.1 + manual fixes, uncommitted), `../adv171-C`, `../adv171-P`
  (patched poms, uncommitted) hold the raw results; the `adv170-*` worktrees from 2026-10-12 are still
  there too.
