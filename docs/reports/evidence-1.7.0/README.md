# Evidence for the Advisor 1.7.0 re-verification (2026-10-12)

Raw captures from the Phase 2 runs described in [`../STATUS-1.7.0.md`](../STATUS-1.7.0.md).
Stack: Advisor **1.7.0**, commercial recipes **1.7.6**, `rewrite-maven-plugin:6.44.0:runNoFork`,
Maven wrapper 3.9.9, Java 25 (librca), macOS. All runs used the kit script from
`advisor-kit/` against detached worktrees; nothing here touched the `advisor` branch.

| File | Scenario |
|---|---|
| `A-dryrun.log`, `A-raw-plan-7mappings.log`, `A-raw-plan-ana.log` | A: guarded Boot 3.4.5 worktree (`ec8552a`), 7 curated mappings — plan hidden by one unmapped transitive (zookeeper), exit 10 |
| `A-raw-plan-8mappings.log`, `A-raw-plan-ana-8mappings.log` | A + generated `zookeeper.json`: 26 projects discovered; plain plan refused with blocker list (exit 50); forced plan = 23-item step |
| `A-force-run.log`, `A-pass1-files-changed.txt`, `A-pom-yml-changes.diff`, `A-java-changes-advisor-plus-manual.diff` | A: kit `--force -y` pass 1 → Boot 4.0.8 in one 4 m 56 s step; the diff also contains the 7 manual API fixes applied afterwards (marked in the java diff by the non-import hunks) |
| `A-compile-fae.log`, `A-install-after-fixes-summary.txt` | A: compile errors after pass 1; reactor status after the manual fixes (non-blocking module still fails: `@RetryableTopic backOff`) |
| `A-force-run-pass2.log` | A: pass 2 — no plan (7 new Kafka-4/Confluent-8 coordinates unmapped) |
| `B-unwired-plan.log` | B: real project, no custom mappings — 18 unmapped coordinates (repro 07 at scale) |
| `B-unguarded-force.log`, `B-hang-final-sample.txt`, `B-jstack.txt` | B: unguarded worktree (`049fdd6`), forced apply HANGS (BUG-7) — depth 35 after 11 min, thread dump |
| `C-dryrun.log`, `C-raw-plan.log`, `C-raw-plan-ana.log` | C: `advisor` branch HEAD (Boot 4.0.8) — no plan, 7 unmapped Kafka-4/Confluent-8 coordinates |
| `C-raw-plan-extended-mappings.log` | C with those coordinates added to the curated mappings: 24 projects, blocker list (exit 50), forced 14-item step offered |
| `C-force-run.log`, `C-pass1-crash-compile-before-rewrite.log` | C pass 1: apply aborts in `process-test-classes` because HEAD does not compile from clean (excerpt of the 26k-line Maven log) |
| `C-force-run-pass2.log`, `C-pass2-pom-changes.diff` | C pass 2 after the `backOff` fix: forced step pins 41 starters to 4.1.1, parent stays 4.0.8 (BUG-8); next step is a 0-file no-op |
| `P-patch-apply.log`, `P-patch-apply-pom-changes.diff`, `P-patch-upgrade-report.json` | `advisor patch apply` on HEAD: transitive patch pins via `<dependencyManagement>`, JSON report |
| `BUG8-minimal-repro.log` | isolation run of the starter-pin defect on a minimal single-module app (no plugin, no custom mappings): 3.4.5 → 3.5.17 → 4.0.8 → 4.1.1 parent, no pins |
| `BUG8-scoping-no-override.log`, `BUG8-no-override-pom-changes.diff` | C worktree, same forced step **without** `spring-boot-jackson3.json:override`: six parents 4.0.8 → 4.1.1, no pins, reactor builds — the diff applied to the `advisor` branch |
