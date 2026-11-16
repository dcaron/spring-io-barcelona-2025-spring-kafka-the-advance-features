# Evidence for the Advisor 1.7.2 re-verification (2026-11-16)

Raw captures from the runs described in [`../STATUS-1.7.2.md`](../STATUS-1.7.2.md).
Stack: Advisor **1.7.2** (`/usr/local/bin/advisor`, binary dated 2026-11-16), commercial recipes **1.7.7**
(1.7.1 used 1.7.6), `rewrite-maven-plugin:6.44.0:runNoFork` (unchanged), Maven wrapper 3.9.9, Java 25
(librca), macOS. No 1.7.2 release notes or coverage page existed on techdocs on this date (the release-notes
page still ends at v1.7.1; `coverage-1-7-2.html` is a 404). All real-project runs used the kit script
from `advisor-kit/` (or `advisor` directly with the same env wiring) against fresh detached worktrees:
`../adv172-A-guarded` and `../adv172-A2` (`ec8552a`, guarded Boot 3.4.5, curated mappings copied from
`advisor` HEAD — `spring-boot-jackson3.json:override` **unwired**, `zookeeper.json` wired in A, unwired in A2),
`../adv172-C`, `../adv172-C2` and `../adv172-P` (all `77fac2c`, `advisor` HEAD, Boot 4.1.1 with the
version-conflict fix of 2026-10-21). Nothing here touched the `advisor` branch. Isolated-repro transcripts
live next to each repro as `repros/*/…-1.7.2.*`.

| File | Scenario |
|---|---|
| `A-dryrun.log`, `A-raw-plan.log`, `A-raw-plan-ana.log`, `A-upgrade-plan*.json` | A: 7 mappings wired — 28 projects discovered (1.7.1: 26; new: `apache-commons-beanutils` replaces the custom `commons-beanutils`, `dropwizard-metrics`, `junit-jupiter`); plain plan refused with **16** blocker lines (1.7.1: 4 — `spring-boot:3.4.x` is now named as the blocker of twelve projects), exit 50; forced plan = one **25-item** step (1.7.1: 24) |
| `A-force-run.log`, `A-pass1-files-changed.txt`, `A-pom-yml-changes.diff`, `A-java-changes-advisor-only.diff`, `A-upgrade-plan-after-force.json` | A: kit `--force -y` pass 1 → **Boot 3.4.5 → 4.1.2 in one 5 m 20 s step**, no starter pins; 6 poms, 10 yml, 7 Java files (Kafka autoconfigure package move in imports/javadoc only); build check fails. (`A-pass1-files-changed.txt` also lists the mapping files copied into the worktree.) |
| `A-compile-fae.log` | A: every compile error after pass 1 (fail-at-end build): the **same five Boot-4 API sites** as on 1.7.0 and 1.7.1 |
| `A-install-after-fixes.txt`, `A-java-changes-advisor-plus-manual.diff` | A: after the five manual fixes + `@RetryableTopic backOff`: `mvnw -DskipTests install` green, six parents at 4.1.2 |
| `A-force-run-pass2.log`, `A-upgrade-plan-pass2.json` | A: pass 2 — forced **9-item** step (kafka 4.3, jackson 3.2, jackson-annotations, commons-validator, commons-io/collections/compress, dropwizard-metrics, xmlunit), "Successfully applied", **0 files** → kit declares convergence at 4.1.2 |
| `A-bug9-probe-no-zookeeper.log`, `A-bug9-probe-upgrade-plan.json`, `A-bug9-probe-upgrade-plan-force.json` | A2 with `zookeeper.json` unwired (6 mappings): **empty** *Projects discovered*, "No upgrade plan available", exit 10 — BUG-9 unchanged; JSON `excludedProjects` lists the 25 projects hidden because of zookeeper; `get -f` → 50 with the real blockers; `get -f --accept-no-alignment` → the 24-item step, exit 0 |
| `C-dryrun.log`, `C-raw-plan.log`, `C-raw-plan-ana.log`, `C-upgrade-plan.json`, `C-upgrade-plan-ana.json` | C (Boot 4.1.1 HEAD): 25 projects; plain plan refused with 13 blocker lines (exit 50); forced plan = 9-item step (1.7.1 D run: 8 — `dropwizard-metrics 2.2.x → 5.0.x` is new) |
| `C-force-run.log`, `C-force-pom-changes.diff`, `C-force-files-changed.txt`, `C-upgrade-plan-after-force.json` | C: kit `--force -y`: step 1 (1 m 25 s) **changes 7 poms** — the project-managed `commons-io` 2.16.1 → 2.22.0 and `commons-compress` 1.26.2 → 1.28.0 (1.7.1: 0 files, because those literals did not exist yet); build green; step 2 = the 7 remaining items, 0 files, converged. Boot stays 4.1.1 (the 4.1.x generation is the mapping's last) |
| `C-ignore-probe.log`, `C-ignore-probe-upgrade-plan.json` | C: the 1.7.1 BUG-10 ignore file (`evidence-1.7.1/C-ignore-probe-3.advisor.yml`) no longer covers the blockers: exit 50 with nine blocker lines; `apply` refuses; `--accept-no-alignment` gives the 9-item step |
| `C-ignore-all-1.7.2.advisor.yml`, `C-ignore-all-probe.log`, `C-ignore-all-upgrade-plan.json` | C2: every slug on either side of a blocker line ignored with `dependencies: "*"` (16 keys) → *"No upgrade plan available … calculated with ignored restrictions"*, **exit 0**, JSON `SUCCEEDED`, `steps: []`, nine blocker-less `blockedUpgrades`; `-d` names no unknown key; `apply` → "There are no upgrade plans", exit 0 — **BUG-10 unchanged** |
| `P-patch-apply.log`, `P-patch-apply-stat.txt`, `P-patch-apply-pom-changes.diff`, `P-patch-upgrade.json`, `P-build-after-patch.txt` | `advisor patch apply` on HEAD: 9 m 42 s, exit 0, *"619 dependency(-ies) upgraded in 7 file(s)"*, +549/−48 lines: **parent 4.1.1 → 4.1.2** (new — 1.7.1 never touched the parent), `confluent.kafka.version` 8.3.1 → 8.3.3, 106 transitive pins added to the existing `<dependencyManagement>` blocks (17 distinct artifacts: jackson 2.21.8, byte-buddy, guava failureaccess, swagger, logredactor, …), and the project's own managed `commons-io` 2.16.1 entry **deleted from all 7 poms** without a replacement or a report entry (BUG-11). Only `target/.advisor/patch-upgrade.json` is written now (108 entries); the 1.7.0-era `.advisor/patch-upgrade-report.json` is gone. The patched reactor builds; effective commons-io/compress versions unchanged (2.16.1 / 1.26.2) |
| `catalog-mapping-search.log`, `catalog-slugs-1.7.2.txt` | `mapping search --slug/--prefix` probes (no kafka/confluent/avro/zookeeper/javafaker/commons-validator slug; `apache-commons-beanutils` now exists) and the **full catalog**, enumerated by recursive prefix search (212 slugs; 30 not on the 1.7.1 coverage page) |

Related captures outside this directory: [`../cli-surface-1.7.2.txt`](../cli-surface-1.7.2.txt)
(byte-identical to 1.7.1 apart from a trailing newline), `repros/*/transcript-1.7.2.txt`,
`repros/01/probe-force-1.7.2.txt`, `repros/02/variants-1.7.2.txt` + `error-stacktrace-single-module-1.7.2.log`
+ `hang-evidence-1.7.2.txt`, `repros/03/probe-override-1.7.2.txt`, `repros/04/generated-org.apache.kafka-1.7.2.json`,
`repros/05/debug-1.7.2.txt`.
