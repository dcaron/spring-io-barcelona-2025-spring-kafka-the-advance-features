# Evidence for the Advisor 1.7.1 re-verification (2026-10-21)

Raw captures from the runs described in [`../STATUS-1.7.1.md`](../STATUS-1.7.1.md).
Stack: Advisor **1.7.1**, commercial recipes **1.7.6** (unchanged), `rewrite-maven-plugin:6.44.0:runNoFork`,
Maven wrapper 3.9.9, Java 25 (librca), macOS. All real-project runs used the kit script from
`advisor-kit/` (or `advisor` directly with the same env wiring) against fresh detached worktrees
`../adv171-A-guarded` (`ec8552a`, guarded Boot 3.4.5, curated mappings copied from `advisor` HEAD —
`spring-boot-jackson3.json:override` **unwired**, `zookeeper.json` wired), `../adv171-C` and
`../adv171-P` (both `5fbf01a`, `advisor` HEAD, Boot 4.1.1). Nothing here touched the `advisor` branch.
Isolated-repro transcripts live next to each repro as `repros/*/…-1.7.1.*`.

| File | Scenario |
|---|---|
| `A-dryrun.log`, `A-raw-plan.log`, `A-raw-plan-ana.log` | A: 8 mappings — 26 projects discovered; plain plan refused with 4 blockers (exit 50); forced plan = one 24-item step |
| `A-bug9-probe-no-zookeeper.log`, `A-bug9-probe-upgrade-plan.json` | A with `zookeeper.json` unwired (7 mappings): 2 projects, "No upgrade plan available", exit 10 — BUG-9 unchanged; the JSON `excludedProjects` lists the 22 projects hidden because of zookeeper |
| `A-force-run.log`, `A-pass1-files-changed.txt`, `A-pom-yml-changes.diff`, `A-java-changes-advisor-only.diff`, `A-upgrade-plan-after-force.json` | A: kit `--force -y` pass 1 → **Boot 3.4.5 → 4.1.1 in one 4 m 13 s step**, no starter pins; 16 pom/yml files, 7 Java files (import/javadoc moves only); build check fails |
| `A-compile-fae.log` | A: every compile error after pass 1 (fail-at-end build): the same 5 Boot-4 API sites as on 1.7.0 |
| `A-install-after-fixes.txt`, `A-java-changes-advisor-plus-manual.diff` | A: after the 5 manual fixes + `@RetryableTopic backOff`: `mvnw -DskipTests install` green |
| `A-force-run-pass2.log`, `A-upgrade-plan-pass2.json` | A: pass 2 — 24 projects, forced 8-item step (jackson 3.2, kafka 4.3, commons-*), "Successfully applied", **0 files** → kit declares convergence at 4.1.1 |
| `C-dryrun.log`, `C-raw-plan.log`, `C-raw-plan-ana.log`, `C-upgrade-plan.json` | C (Boot 4.1.1 HEAD): 24 projects; plain plan refused with 7 blockers (exit 50); forced plan = 8-item step; the `upgrade-plan.json` written by `get` |
| `C-ignore-probe.log`, `C-ignore-probe-2.log`, `C-ignore-probe-3.log`, `C-ignore-probe-3.advisor.yml`, `C-ignore-probe-3b-flags.log` | C: `.advisor.yml` `upgrade.ignore` probes — key semantics, then all blockers ignored → empty plan, exit 0 (BUG-10); `--accept-no-alignment` / `-f` / `--squash-all` on top |
| `C-force-run.log`, `C-upgrade-plan-after-force.json` | C: kit `--force -y`: the 8-item step reports success, changes **0 files**, JSON says `SUCCEEDED` |
| `P-patch-apply.log`, `P-patch-apply-pom-changes.diff`, `P-patch-upgrade.json`, `P-patch-upgrade-report.json` | `advisor patch apply` on HEAD: 8 m 14 s, 278 pins in 7 poms (+975 lines), `avro.version` 1.12.0 → 1.12.2; both report files (documented `target/.advisor/patch-upgrade.json` and the 1.7.0-era `.advisor/patch-upgrade-report.json`) |
| `catalog-mapping-search.log` | `mapping search --slug/--prefix` for the Kafka/Confluent/Avro/Zookeeper/commons slugs: none exist; `apache-commons-io`, `azure-core` do (FR-1) |

Related captures outside this directory: [`../cli-surface-1.7.1.txt`](../cli-surface-1.7.1.txt)
(identical to 1.7.0), [`../release-notes-1.7.x.txt`](../release-notes-1.7.x.txt) (techdocs text of
the 1.7.0 and 1.7.1 notes, published 2026-10-20).
