# Advisor defects in Simplified Technical English

This document describes the ten Advisor defects in Simplified Technical English (ASD-STE100).
Each description has the same parts: Condition, Problem, Cause, Effect, Workaround, Status and Evidence.
The full technical reports are in this directory (`BUG-1-…` to `BUG-10-…`). The status is valid for
Advisor 1.7.1 on 2026-10-21.

Terms used in this document:

- **Advisor**: the Spring Application Advisor command-line tool.
- **plan**: the list of upgrade steps that `advisor upgrade-plan get` shows.
- **apply**: the command `advisor upgrade-plan apply`.
- **forced apply**: the command `advisor upgrade-plan apply --accept-no-alignment`.
- **mapping**: a JSON file that tells Advisor the versions and recipes of one project.
- **custom mapping**: a mapping that you supply with the `SPRING_ADVISOR_MAPPING_CUSTOM_<N>_FILEPATH` variable.
- **slug**: the project name inside a mapping, for example `kafka`.
- **transitive dependency**: a dependency that your project does not declare, but that a declared dependency uses.
- **the kit**: the scripts and mappings in `advisor-kit/`.

---

## BUG-1 — Apply reports success but changes no file

**Condition.** The project has a dependency that only comes as a transitive dependency. The pom has no
version literal for it. The mapping for this dependency has an upgrade.

**Problem.** On Advisor 1.6.x, apply selects this upgrade, reports "Successfully applied", and changes
no file. The next apply selects the same upgrade again. This loop does not stop.

**Cause.** The recipe has no version literal to change. Advisor does not detect that the step changed
nothing.

**Effect.** The default upgrade path cannot make progress on this project. Automation that reads
"Successfully applied" believes that the upgrade is complete.

**Workaround.** Use the forced apply. The kit does this in `--force` mode. Stop when the worktree does
not change.

**Status on 1.7.1.** Partly corrected since 1.7.0. The default apply now refuses the plan with a list of
blockers and exit code 50. It changes nothing. The forced apply can still report success for a step
that changes no file.

**Evidence.** `repros/01-apply-noop-loop/`, `evidence-1.7.1/C-force-run.log`.

---

## BUG-2a — The recipe bundle does not include a class that the recipes use

**Condition.** The forced apply reaches the Spring Boot 4 step.

**Problem.** The step fails with "Recipe class not found:
org.openrewrite.java.dependencies.search.ModuleHasDependency".

**Cause.** The Boot 4 recipes use the class `ModuleHasDependency`. That class is in the artifact
`rewrite-java-dependencies`. Advisor does not put this artifact in the recipe coordinates that it gives
to Maven. Maven then resolves an old version of the artifact, or no version.

**Effect.** The upgrade to Spring Boot 4 fails for projects that declare the `rewrite-maven-plugin`
with plugin dependencies.

**Workaround.** Move the whole `rewrite-maven-plugin` declaration into a Maven profile that is not
active. The kit gives a template for this.

**Status on 1.7.1.** Not corrected. The failed apply now returns exit code 30.

**Evidence.** `repros/02-missing-recipe-bundle/variants-1.7.1.txt`,
`repros/02-missing-recipe-bundle/error-stacktrace-single-module-1.7.1.log`.

---

## BUG-2b — Apply runs the project's own rewrite plugin

**Condition.** The project has more than one Maven module. A pom binds the `rewrite-maven-plugin` to
a lifecycle phase.

**Problem.** Apply runs the Maven phase `process-test-classes` before its own goal. This phase runs
the project's plugin execution. The execution receives Advisor's `-Drewrite.*` properties and tries to
run Advisor's recipes.

**Cause.** Advisor adds a lifecycle phase to its Maven command for multi-module projects. It does not
isolate its properties from the project's plugin executions.

**Effect.** The project's plugin fails or hangs (see BUG-7). The apply stops.

**Workaround.** Same as BUG-2a: move the plugin declaration into a profile that is not active.

**Status on 1.7.1.** Not corrected. The execution hangs (BUG-7).

**Evidence.** `repros/02-missing-recipe-bundle/`, `evidence-1.7.0/B-unguarded-force.log`.

---

## BUG-3 — Advisor commands load custom mappings with the same slug differently

**Condition.** Two custom mappings have the same slug.

**Problem.** `build-config get` accepts the two mappings. `upgrade-plan get` rejects the second mapping
with the message "Failed to load the mapping source. Please verify the source configuration."
`mapping create` stops with an internal error. Only the error log shows the cause: "Some projects were
already defined: [kafka]".

**Cause.** The three commands use different mapping loaders. One loader is tolerant. The other two
loaders are strict.

**Effect.** You cannot wire two generated mappings for modules of the same project family. The
generic message does not tell you why the mapping is rejected.

**Workaround.** Keep one mapping file for each slug. The kit detects a collision and does not wire
the second file.

**Status on 1.7.1.** Not corrected.

**Evidence.** `repros/03-dup-slug-inconsistent-loading/`.

---

## BUG-4 — `mapping create` writes a hidden file for an empty slug

**Condition.** You run `advisor mapping create -c=org.apache.kafka:kafka_2.13`.

**Problem.** Advisor computes an empty slug. It writes the mapping to `.advisor/mappings/.json`. This
file is hidden. There is no option to select the output file name. When the slug is not empty and a
file with that name exists, Advisor overwrites the file without a message.

**Cause.** Advisor uses the slug as the file name and does not validate it.

**Effect.** You do not see the generated mapping. A curated mapping can be lost.

**Workaround.** The kit copies the generated content to a file name that it selects. It restores the
mappings directory after each `mapping create`.

**Status on 1.7.1.** Not corrected.

**Evidence.** `repros/04-empty-slug-hidden-file/`.

---

## BUG-5 — Version resolution ignores the repositories in the pom

**Condition.** The pom declares a Maven repository, for example the Confluent repository. A dependency
comes only from that repository.

**Problem.** `mapping create` reports "No versions found. One or more repositories denied access
(HTTP 401/403). Check the credentials in ~/.m2/settings.xml." Maven itself resolves the dependency
without a problem.

**Cause.** Advisor resolves versions with its own repository list. It does not read the repositories
from the project pom. The option `-d` shows this list: Maven Central, `repo.spring.io`, the repository
in `settings.xml`, and the local repository. The Confluent repository from the pom is not in the list.

**Effect.** You cannot generate a mapping for Confluent artifacts. The error message points to the
wrong cause.

**Workaround.** The kit's curated `confluent-platform.json` contains the repository URL.

**Status on 1.7.1.** Not corrected. `mapping update` has the same problem.

**Evidence.** `repros/05-resolution-ignores-repositories/`.

---

## BUG-6 — Advisor ignores an empty custom mapping without a message

**Condition.** A wired custom mapping contains only `{}`.

**Problem.** `build-config get` and `upgrade-plan get` complete without a warning. Nothing names
the empty file.

**Cause.** Advisor skips the mapping and does not report it.

**Effect.** A truncated or wrong mapping stays unnoticed. Its project goes back to the blocked list.

**Workaround.** The kit validates each mapping before it wires the mapping.

**Status on 1.7.1.** Not corrected.

**Evidence.** `repros/06-empty-mapping-silent-skip/`.

---

## BUG-7 — The project's rewrite plugin hangs in a recursive recipe scan

**Condition.** Same as BUG-2b. The recipe version is 1.7.6 or later.

**Problem.** The first forced apply step does not stop. The Maven child process uses all CPU cores and
more than 4 GB of memory. A thread dump shows the method `UpgradeJackson_2_3_ApiOnly.getRecipeList`
more than 30 times in the call stack.

**Cause.** The project's old plugin version loads the new recipes. The recipe
`UpgradeJackson_2_3_ApiOnly` calls `Environment.activateRecipes`. That call scans the classpath and
builds the recipe descriptors. The descriptor of the same recipe calls the method again. There is no
end to this recursion.

**Effect.** The apply never completes. You must stop the process by hand. On 1.6.7 the same step
completed in 39 seconds and then failed at the Boot 4 step (BUG-2a).

**Workaround.** Same as BUG-2b: move the plugin declaration into a profile that is not active. The
kit refuses to run when the declaration is not guarded. Stop a hung run with `pkill -f runNoFork`.

**Status on 1.7.1.** Not corrected. The bounded test stopped the process after 612 seconds at
recursion depth 36.

**Evidence.** `repros/02-missing-recipe-bundle/run-1.7.0-hang.sh`,
`repros/02-missing-recipe-bundle/transcript-1.7.1.txt`, `hang-jstack-full-1.7.0.txt`.

---

## BUG-8 — The forced Boot 4.1 step pins the starters and keeps the old parent

**Condition.** A custom mapping with the `override` strategy replaces the `spring-boot` mapping. This
custom mapping does not define the 4.1.x generation. The project is on Spring Boot 4.0.x.

**Problem.** The forced step "spring-boot 4.0.x → 4.1.x" reports success. The parent stays at 4.0.8.
Each `spring-boot-starter-*` dependency receives `<version>4.1.1</version>`. The project then uses
starters from 4.1.1 on core modules from 4.0.8.

**Cause.** The effective mapping has no definition for the target generation. Advisor does not detect
this. It pins each dependency instead of moving the parent.

**Effect.** The build mixes two Spring Boot generations. The build still compiles, so the problem is
easy to miss.

**Workaround.** Do not wire a `spring-boot` override mapping that does not define the target
generation. The kit no longer wires `spring-boot-jackson3.json`. If a run already added the pins,
remove the pins and move the parent by hand.

**Status on 1.7.1.** Not tested again with the trigger. Without the override mapping, the project
goes from 3.4.5 to 4.1.1 in one step and receives no pins.

**Evidence.** `evidence-1.7.0/C-pass2-pom-changes.diff`, `evidence-1.7.0/BUG8-minimal-repro.log`,
`evidence-1.7.1/A-pom-yml-changes.diff`.

---

## BUG-9 — One transitive dependency without a mapping hides the whole plan

**Condition.** One transitive dependency has no mapping, for example `org.apache.zookeeper:zookeeper`.
All other dependencies have mappings.

**Problem.** `upgrade-plan get` shows two projects and "No upgrade plan available". It returns exit
code 10. Only a warning names the dependency. On 1.6.7 the same project showed 20 projects and a
full plan. After you wire a mapping for zookeeper, Advisor shows 26 projects and a 24-item plan.

**Cause.** Advisor removes each project that depends on the unmapped dependency from the plan. The
console does not report this removal. The JSON report does: `excludedProjects` lists the 22 removed
projects.

**Effect.** A Spring Boot 3.4.5 project looks almost up to date. The release notes for 1.7.0 say the
opposite: "Only missing mappings for your direct dependencies block the plan."

**Workaround.** Use the option `-f` (`--force`) with `upgrade-plan get` and `upgrade-plan apply`. The
documentation says that this option continues the plan when dependencies have no mapping. The test
shows that `get -f` finds 25 projects and `get -f --accept-no-alignment` gives the full step. Or wire
a mapping for each transitive dependency in the warning. The kit does both: it creates mappings first
and then uses `-f` for the dependencies that remain.

**Status on 1.7.1.** Not corrected, but a documented option avoids the problem. Two differences with
the documentation remain. The default run does not calculate the plan. With `-f`, Advisor does not
list the dependency as a warning. It removes the dependency from the console and from the JSON report.

**Evidence.** `evidence-1.7.1/A-bug9-probe-no-zookeeper.log`,
`evidence-1.7.1/A-bug9-probe-upgrade-plan.json`, `release-notes-1.7.x.txt`.

---

## BUG-10 — With all restrictions ignored, the plan is empty and the exit code is 0

**Condition.** The plan is refused with a list of blockers (exit code 50). You add a `.advisor.yml`
file with an `upgrade.ignore` section that ignores each restriction. This is the procedure that the
1.7.0 release notes give.

**Problem.** `upgrade-plan get` prints "No upgrade plan available" and "Upgrade Plan was calculated
with ignored restrictions". It returns exit code 0. The JSON report shows `"status": "SUCCEEDED"`,
an empty `steps` list, and eight `blockedUpgrades` entries with no blocker project. Only
`--accept-no-alignment` then gives the step. The options `-f` and `--squash-all` do not.

**Cause.** Dependency-alignment conflicts still hold back the plan. In this project the conflicts
are in the project itself: two versions of `commons-lang3`, three versions of Jackson. The
documentation calls this a triangular dependency misalignment. The documented action is to correct
the conflict in the pom, or to use `--accept-no-alignment`. Advisor does not report these conflicts as
blockers. It reports success. The documentation says that an entry with no blocker project means
"the project needs a migration that the upgrade mappings do not define", and that such an entry gives
no exit code. The exit code 0 follows this rule. The state is still wrong. A second test, after the
correction of the version conflicts in the poms, shows the same result: all twelve blocker slugs
ignored, no plan, exit code 0. The defect does not depend on the conflicts.

**Effect.** A pipeline that reads the exit code or the JSON status decides that there is nothing to
upgrade. The project has eight pending upgrades.

**Note on the ignore key.** The key in `upgrade.ignore` is the slug of the mapping that declares the
restriction. For some blocker lines this is the first slug in the line (`jackson` for
`jackson-annotations`). For other blocker lines this is the second slug (`apache-commons-io` for
`apache-commons-lang`). The console does not tell you which slug to use.

**Workaround.** Do not use the exit code alone. Make sure that `steps` in `upgrade-plan.json` is not
empty. The kit reports this condition and tells you to use `--force`.

**Status on 1.7.1.** New. Found on 2026-10-21.

**Evidence.** `evidence-1.7.1/C-ignore-probe.log`, `C-ignore-probe-2.log`, `C-ignore-probe-3.log`,
`C-ignore-probe-3.advisor.yml`, `C-ignore-probe-3b-flags.log`.
