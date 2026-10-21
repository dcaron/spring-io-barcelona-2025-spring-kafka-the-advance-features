# App team runbook — upgrade your application

Follow these steps in order. The whole run is safe to repeat.
To run the upgrade from your CI pipeline instead, see `ci-pipeline.md`.

## Before you start

- [ ] Your git worktree is clean. You are on a fresh branch.
- [ ] `advisor --version` prints 1.7.x (1.6.x still works).
- [ ] `~/.m2/settings.xml` has your Spring Enterprise credentials.
- [ ] You know where the kit is (this directory).

## Step 1 — guard the rewrite-maven-plugin

Maven merges a build-level `rewrite-maven-plugin` declaration into Advisor's
own apply run. On Advisor 1.6.x that breaks the upgrade; on 1.7.x it hangs the
run for good (BUG-7). Move the declaration into a profile.

1. Open your root `pom.xml`.
2. Move the whole plugin declaration into a profile.
   Use the template: `snippets/rewrite-plugin-profile-guard.xml`.
3. Run your own recipes later with `mvn -Popenrewrite validate`.

The script checks this and refuses to run while the plugin is unguarded.
If your repo does not declare the plugin, skip this step.

## Step 2 — dry run

```
./advisor-kit/advisor-upgrade.sh --dry-run <repo-dir>
```

Read the plan. The "Projects discovered" lines show the intended upgrades.
The "blocked" list shows dependencies without a mapping. The script creates
missing mappings automatically where it can. On Advisor 1.7.x expect
`advisor exit 50` with a blocker summary in plain mode: that is normal for this
class of project and is why step 3 uses `--force`. If the plan shows only one
or two projects on an old Boot version, a transitive dependency without a
mapping is hiding the rest (BUG-9); the "blocked" list names it.

Your project must compile from a clean checkout before you start. Advisor
compiles every module before it rewrites anything, and aborts on the first
compile error.

## Step 3 — apply

```
./advisor-kit/advisor-upgrade.sh --force -y <repo-dir>
```

Use `--force`. Plain apply never lands on this class of project: on 1.6.x it
reports success but changes no files (BUG-1), on 1.7.x it refuses with a
blocker list. `--force` runs `apply --accept-no-alignment` repeatedly until
the worktree stops changing. Expect a small number of passes; on 1.7.0 the
Boot 3.4 → 4.0 upgrade landed in one five-minute step, and on 1.7.1 (with no
`spring-boot` override mapping wired) Boot 3.4 → **4.1** landed in one
four-minute step.

## Step 4 — fix compile breaks and review version pins

Advisor's recipes do not cover every API removal. Fix the rest by hand.
On 1.7.0 the recipes already migrate the `org.springframework.boot.autoconfigure.kafka`
→ `org.springframework.boot.kafka.autoconfigure` package move, the starter renames
(`spring-boot-starter-web` → `-webmvc`, `spring-kafka` → `spring-boot-starter-kafka`),
the OTLP tracing properties and the health-probe default. Known breaks after a
Boot 3 → 4 upgrade that remain:

| Old code                                            | Fix                                   |
|-----------------------------------------------------|---------------------------------------|
| `kafkaProperties.buildConsumerProperties(sslBundles)` | Call `buildConsumerProperties()` with no argument. Remove the unused `SslBundles` parameter and import. |
| `consumer.buildProperties(null)`                    | Call `buildProperties()` with no argument. |
| `PropertyMapper.get().alwaysApplyingWhenNonNull()`  | Call `PropertyMapper.get()`. Delete the modifier. |
| `map.from(x).whenNonNull().to(...)`                 | Delete `.whenNonNull()`. Non-null filtering is the Boot 4 default. |
| `@RetryableTopic(backoff = @Backoff(...))` with `org.springframework.retry.annotation.Backoff` | Spring Kafka 4 dropped spring-retry here: `backOff = @BackOff(...)` with `org.springframework.kafka.annotation.BackOff` (same `delay`/`multiplier`/`maxDelay` attributes). |

Build after each fix from clean: `./mvnw clean -DskipTests install`. An
incremental build can pass on stale classes and hide a break.

Then review the poms (BUG-8, Advisor 1.7.0): if a `spring-boot` override mapping
is wired (the kit no longer wires `spring-boot-jackson3.json`), the
"spring-boot 4.0.x → 4.1.x" step leaves the parent at 4.0.x and gives every
`spring-boot-starter-*` dependency an explicit `<version>4.1.1</version>`.
Remove those pins (let the parent manage the versions) and move the parent to
4.1.x, or revert and re-run with the override unwired. Do not ship mixed Boot
generations.

## Step 5 — validate and commit

1. Run the tests: `./mvnw test`.
2. Start the application against your local infrastructure. Verify behaviour.
3. Commit the source changes AND `.advisor/mappings/`. The mappings make the
   run reproducible.

## Troubleshooting

| Symptom                                            | Cause | Action                                    |
|----------------------------------------------------|-------|-------------------------------------------|
| Apply reports success, but no files change         | BUG-1 | Re-run with `--force`.                    |
| "Some projects were already defined: [...]"        | BUG-3 | Two mappings share a slug. Remove one. See `known-issues.md`. |
| "One of the custom mappings provided is empty"     | BUG-6 | Delete the empty file from `.advisor/mappings/`. Re-run. |
| "Recipe class not found: ...ModuleHasDependency"   | BUG-2 | Your pom still declares the rewrite plugin. Do step 1. |
| Apply runs for an hour, Maven at 100 % per core, no output | BUG-7 | `pkill -f runNoFork`. Your pom still declares the rewrite plugin. Do step 1. |
| Plan shows 1–2 projects, "No upgrade plan available", exit 10 | BUG-9 | A transitive dependency has no mapping; the script's blocked list names it. Re-run: the script creates the mapping. |
| Starters pinned to 4.1.1, parent still 4.0.x        | BUG-8 | Step 4, pin review. |
| Apply fails compiling a module before any rewrite  | —     | The project must compile from clean first. Fix, then re-run. |
| A dependency stays blocked after auto-mapping      | Gap   | Report it to the framework team.          |

## Report problems to the framework team

Attach: the script output, the newest log in `.advisor/errors/`, your
`.advisor/mappings/` directory, and your root `pom.xml`.
