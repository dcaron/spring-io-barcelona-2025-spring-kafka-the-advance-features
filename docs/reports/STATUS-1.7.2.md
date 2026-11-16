# Advisor 1.7.2 — re-verification of every finding (2026-11-16)

| | |
|---|---|
| Advisor | **1.7.2** (`/usr/local/bin/advisor`, binary dated 2026-11-16), commercial recipes **1.7.7** (1.7.1: 1.7.6), `rewrite-maven-plugin:6.44.0:runNoFork` (unchanged) |
| Previous | 1.7.1, recipes 1.7.6 — [`STATUS-1.7.1.md`](STATUS-1.7.1.md) |
| Release notes | **None published yet.** The techdocs release-notes page still ends at v1.7.1 and `coverage-1-7-2.html` is a 404 (checked 2026-11-16). Everything below is observed behaviour; what Broadcom intended to fix is unknown. |
| CLI surface | [`cli-surface-1.7.2.txt`](cli-surface-1.7.2.txt) is byte-identical to 1.7.1 (one trailing newline) |
| Evidence | [`evidence-1.7.2/`](evidence-1.7.2/README.md) (real project), `repros/*/…-1.7.2.*` (isolated repros) |
| Method | Same three phases as 1.7.0/1.7.1: the 8 isolated repros (+ the single-module BUG-2a variant, the bounded BUG-7 hang script, catalog probes and a full catalog enumeration); the real project from Boot 3.4.5 (guarded worktree `ec8552a`, curated mappings) and from `advisor` HEAD (Boot 4.1.1, `77fac2c`), driven by the kit script; `patch apply`; BUG-9 and BUG-10 probes. |

**Headline.** 1.7.2 is the first 1.7.x release that changes behaviour this project can see, mostly in
`mapping create` and the catalog. One defect is fixed (BUG-4, the hidden `.json` file), one is half
fixed (BUG-3, the duplicate-slug message now names the slug and the remedy), the catalog gained
`apache-commons-beanutils` and `dropwizard-metrics` (30 new slugs in all), the recipes moved to 1.7.7
and now take Boot 3.4.5 to **4.1.2** in one forced step, and `patch apply` moves the parent to the
latest patch instead of pinning starters. Nothing improved for the heavy defects: the forced apply
still hangs on an unguarded multi-module project (BUG-7), still needs the same five manual Boot-4 API
fixes afterwards, one unmapped transitive still hides the whole plan (BUG-9), and "empty plan, exit 0"
(BUG-10) now also happens with no `.advisor.yml` at all, because the new catalog mapping silently
supersedes a wired custom one (BUG-1 repro). One new defect: `patch apply` deleted a project-managed
`commons-io` version from all seven poms without reporting it (BUG-11).

## 1. Per-issue verdicts

| Issue | 1.7.1 | 1.7.2 | Verdict |
|---|---|---|---|
| BUG-1 apply no-op loop | blocker summary, exit 50; forced path 0-file "success" | repro: catalog `apache-commons-beanutils` supersedes the custom mapping → **no blocker summary, exit 0**, JSON `SUCCEEDED` with two blocker-less `blockedUpgrades`; forced path still a 0-file "success" (`repros/01/transcript-1.7.2.txt`, `probe-force-1.7.2.txt`). Real project: forced pass 2 on A and step 2 on C = 0 files | **Regressed signal**, no-op unchanged |
| BUG-2a missing `rewrite-java-dependencies` | `ModuleHasDependency` at the Boot-4 step, exit 30 | identical with recipes 1.7.7, still seven `com.vmware.tanzu.spring.recipes:*` coordinates (`repros/02/variants-1.7.2.txt`) | Unchanged |
| BUG-2b project plugin hijack | hangs (BUG-7) | hangs; `process-test-classes` still prepended | Unchanged |
| BUG-3 duplicate slug | generic reject / crash | `upgrade-plan get` now says *"Slug(s) demo are already defined by another mapping source. To replace … set 'merge-strategy' to 'OVERRIDE' … To keep both … rename the slug"*; with `MERGE_STRATEGY=override` the plan works and `mapping create` stops crashing (`repros/03/probe-override-1.7.2.txt`). `build-config` still silent, `mapping create` without override still crashes (typed `DuplicateMappingSlugException`, log only) | **Partially fixed** |
| BUG-4 empty-slug hidden file | `.advisor/mappings/.json`, slug `""` | writes `org.apache.kafka.json`, slug `org.apache.kafka` (groupId fallback). No `-o` yet (`repros/04/transcript-1.7.2.txt`) | **Fixed** |
| BUG-5 pom repositories ignored | misblames credentials | identical; `-d` still lists four repositories, never the pom's (`repros/05/debug-1.7.2.txt`) | Unchanged |
| BUG-6 empty mapping silent | no warning | identical (new 7th build-config step *"Obtaining parent artifacts"*) | Unchanged |
| BUG-7 hijack hangs | depth 36, killed at 612 s | depth 34–36 from 2 min on, 4.4 GB, up to 9 cores, killed at the cap, pom untouched (`repros/02/hang-evidence-1.7.2.txt`) | Unchanged |
| BUG-8 forced 4.1 step pins starters | not re-triggered | not re-triggered: A goes 3.4.5 → **4.1.2** in one step, no pins; `patch apply` now moves the parent 4.1.1 → 4.1.2 itself | Not re-triggered |
| BUG-9 unmapped transitive hides plan | 2 projects shown, exit 10, 22 hidden | **0** projects shown, exit 10, **25** hidden in JSON `excludedProjects`; `-f` workaround unchanged (`evidence-1.7.2/A-bug9-probe-*`) | Unchanged |
| BUG-10 ignore-all → empty plan, exit 0 | reproduced | reproduced with all 16 blocker slugs ignored (`evidence-1.7.2/C-ignore-all-*`); **and** the same end state now appears in repro 01 with no ignore file | Unchanged, wider |
| **new** [BUG-11](BUG-11-patch-apply-deletes-managed-dependency.md) | — | `patch apply` deletes the project's managed `commons-io` 2.16.1 from all 7 poms; not in `patch-upgrade.json`, not on the console; effective version unchanged here, build green | New |
| FR-1 first-party Kafka/Confluent | none | none in a full enumeration of the 212-slug catalog (`evidence-1.7.2/catalog-slugs-1.7.2.txt`); 30 new slugs incl. `apache-commons-beanutils`, `dropwizard-metrics`; repro 07 lists 15 unmapped transitives (was 16) | Still needed |
| FR-2 family-aware create | slug collapse | identical for `kafka-metadata`/`kafka-group-coordinator` (slug `kafka`), while `kafka_2.13` now gets `org.apache.kafka` — two slug styles in one family | Still needed |
| FR-3 machine-readable plan | largely addressed | unchanged; `patch apply` now writes only the documented `target/.advisor/patch-upgrade.json` (the `.advisor/patch-upgrade-report.json` twin is gone) | Mostly closed |
| FR-4 declarative wiring | env vars | env vars; new reason: a catalog mapping can silently supersede a wired custom mapping with overlapping coordinates | Still needed |

## 2. What changed in 1.7.2 (observed, undocumented)

- **Recipes 1.7.7.** Boot target is now 4.1.2 (released since 2026-10-21), confluent property → 8.3.3.
  The recipe output on this project is otherwise the same as 1.7.6: Kafka autoconfigure package move in
  seven Java files (imports/javadoc), starter renames (`web → webmvc`, `spring-kafka → starter-kafka`,
  `starter-opentelemetry` added), OTLP property migration and the `probes.enabled: false` TODO in every
  `application.yml`.
- **Catalog.** 212 slugs enumerated by recursive `mapping search --prefix` (the command shows at most ten
  hits per query). Not on the 1.7.1 coverage page: `apache-commons-beanutils`,
  `apache-commons-configuration2`, `apache-commons-net`, `dropwizard-metrics`, `gradlew`, `groovy`,
  `junit-jupiter`, `junit-vintage`, `mcp`, `mcp-json-jackson2`, `mcp-json-jackson3`, `mvnw`, and 18
  `spring-*` slugs (`spring-data`, `spring-shell`, `spring-statemachine`, legacy `spring-roo`/`spring-xd`/…).
  Still nothing for Kafka, Confluent, Avro, Zookeeper, javafaker, commons-validator.
- **Catalog wins over custom.** The wired `commons-beanutils.json` (slug `commons-beanutils`) is silently
  displaced by the catalog's `apache-commons-beanutils` for the same coordinate — the plan lists the
  catalog slug and nothing mentions the overlap. Only *same-slug* conflicts are detected (BUG-3).
- **Messages.** Duplicate-slug rejection names the slug and the two remedies; a seventh build-config
  step *"Obtaining parent artifacts"*; `mapping create` falls back to the groupId as slug.
- **Blocker reporting.** On Boot 3.4.5 the plain plan now names `spring-boot:3.4.x` as the blocker of
  twelve projects (16 blocker lines, 1.7.1: 4). Same exit 50, same forced plan.
- **`patch apply`.** Moves the Boot parent to the latest patch (4.1.1 → 4.1.2) instead of leaving it;
  adds its pins to the project's existing `<dependencyManagement>` block (1.7.1 created a new block per
  module); 619 upgrades / 108 report entries / 17 distinct pinned artifacts (1.7.1: 278 / 56 / 51); only
  one report file. And BUG-11.

## 3. Real-project scenarios

### A — guarded Boot 3.4.5 worktree, curated mappings (`evidence-1.7.2/A-*`)

1. Plain plan: 28 projects discovered, refused with 16 blocker lines, exit 50. Forced plan: one 25-item
   step (new items: `apache-commons-beanutils`, `dropwizard-metrics 4.1.x → 5.0.x`, `junit-jupiter`
   instead of `junit`; `spring-retry` migrates into `spring-framework 7.0.x`).
2. `--force -y`: **one step, 5 m 20 s, Boot 3.4.5 → 4.1.2** in all six app modules, no pins; 6 poms,
   10 yml, 7 Java files.
3. Build check: the **same five compile sites** as 1.7.0/1.7.1 — `KafkaProperties.buildConsumerProperties(SslBundles)`
   ×3, `Consumer.buildProperties(null)`, `PropertyMapper.alwaysApplyingWhenNonNull()` — plus the
   unmigrated `@RetryableTopic(backoff = @Backoff)`. After the same manual edits the reactor installs
   green on Boot 4.1.2.
4. Pass 2: forced 9-item step, *"Successfully applied"*, **0 files**; the kit stops. No `zookeeper`
   exclusion this time (mapping wired).

### BUG-9 probe (`evidence-1.7.2/A-bug9-probe-*`)

A2, `zookeeper.json` unwired: *Projects discovered* empty, exit 10, `excludedProjects` = zookeeper with 25
projects. `get -f` → 50 with the real blockers; `get -f --accept-no-alignment` → the 24-item step, exit 0.

### C — `advisor` HEAD, Boot 4.1.1 (`evidence-1.7.2/C-*`)

1. Plan: 25 projects, refused with 13 blocker lines (exit 50); forced plan = 9-item step.
2. `--force -y`: step 1 (1 m 25 s) **changes 7 poms** — the managed `commons-io` 2.16.1 → 2.22.0 and
   `commons-compress` 1.26.2 → 1.28.0 that the 2026-10-21 conflict fix introduced; build green; step 2 =
   the remaining 7 items, 0 files; converged. Boot stays 4.1.1: the forced plan has no Boot step because
   4.1.x is the generation's last mapping entry (the patch move to 4.1.2 is `patch apply`'s job, see P).
3. BUG-10: the 1.7.1 ignore file leaves nine blockers (exit 50); ignoring all sixteen slugs reproduces
   the empty plan with exit 0 (C2).

### `patch apply` (`evidence-1.7.2/P-*`)

9 m 42 s, exit 0, 7 poms, +549/−48: parent 4.1.1 → 4.1.2, `confluent.kafka.version` 8.3.1 → 8.3.3, 106
transitive pins (jackson 2.21.8, byte-buddy 1.18.17, swagger-annotations-jakarta 2.2.55, logredactor,
failureaccess, …) added to the existing `<dependencyManagement>` blocks, and the managed `commons-io`
entry removed from all seven poms (BUG-11). The patched reactor builds; effective commons-io/compress
unchanged. Same caveat as before: the pins override the Boot BOM — review before adopting, or try
`--skip-transitive-deps`.

## 4. What changed in this repository because of 1.7.2

- No source or mapping changes: the `advisor` branch stays at Boot 4.1.1 (nothing applied). Adopting
  4.1.2 and the commons-io/compress bumps from worktrees `../adv172-C` / `../adv172-P` is a separate
  decision (the C diff is two version literals per pom; the P diff needs review).
- New: this file, [`BUG-11`](BUG-11-patch-apply-deletes-managed-dependency.md), [`evidence-1.7.2/`](evidence-1.7.2/README.md),
  [`cli-surface-1.7.2.txt`](cli-surface-1.7.2.txt), `repros/*/…-1.7.2.*`; every report has a *"Status on
  Advisor 1.7.2"* section; `README.md`, `DEFECTS-STE.md`, `docs/advisor-improvements.md` §1f,
  `docs/advisor-support-ticket.md`, `docs/kafka-mappings-ticket.md` and the kit docs updated.
- Kit: version gate text (verified on 1.7.0, 1.7.1 and 1.7.2); `known-issues.md` rows for BUG-1/3/4/10/11
  and the catalog-wins-over-custom note. Behaviour of the script needed no change: it read the 1.7.2
  plans correctly, applied, built, and declared convergence.
- Worktrees `../adv172-A-guarded` (Boot 4.1.2 + manual fixes, uncommitted), `../adv172-A2`, `../adv172-C`
  (commons-io/compress bumps), `../adv172-C2`, `../adv172-P` (patched poms) hold the raw results; the
  `adv170-*` and `adv171-*` worktrees from the earlier runs are still there too.

## 5. Open points

- File BUG-7/9/10 (unchanged), BUG-11 (new) with Broadcom; close BUG-4 in the ticket; narrow BUG-3 to
  "same validation in all three commands + root cause on the console". For BUG-1/BUG-10 attach
  `repros/01/transcript-1.7.2.txt`: an empty plan with exit 0 from ordinary input.
- Re-check techdocs for the 1.7.2 release notes and coverage page; reconcile §2 with them when they appear.
- Kit: consider warning when a catalog slug claims a coordinate that a wired custom mapping also claims
  (compare `mapping search` results with the curated files) — Advisor does not.
- Watch the next recipes release for the five Boot-4 API sites and `@RetryableTopic backOff`.
