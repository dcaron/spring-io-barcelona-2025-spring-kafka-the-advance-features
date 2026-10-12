# Advisor crash logs kept as evidence

`20260820-141119353.log` — Advisor **1.6.7**, `upgrade-plan apply --accept-no-alignment` on this
repo (2026-08-20, before the rewrite-plugin profile guard). Stack: `rewrite-maven-plugin:6.44.0:runNoFork`,
commercial recipes `1.7.5`. Fails with `Recipe class not found:
org.openrewrite.java.dependencies.search.ModuleHasDependency` (BUG-2a/2b, `docs/reports/`).
Two further logs from the same afternoon (14:16, 14:20) were byte-identical apart from run
UUIDs and timing counters and were not committed.

Advisor writes new crash logs here on every failure; commit only those that are evidence for a report.

Note: 14 occurrences of the Spring Enterprise repository access token (a JFrog platform token Maven echoed in -X debug output) were replaced with `<REDACTED-JFROG-TOKEN>` before committing.
