# App team runbook — upgrade your application

Follow these steps in order. The whole run is safe to repeat.

## Before you start

- [ ] Your git worktree is clean. You are on a fresh branch.
- [ ] `advisor --version` prints 1.6.x.
- [ ] `~/.m2/settings.xml` has your Spring Enterprise credentials.
- [ ] You know where the kit is (this directory).

## Step 1 — guard the rewrite-maven-plugin

Maven merges a build-level `rewrite-maven-plugin` declaration into Advisor's
own apply run. That breaks the upgrade. Move the declaration into a profile.

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
missing mappings automatically where it can.

## Step 3 — apply

```
./advisor-kit/advisor-upgrade.sh --force -y <repo-dir>
```

Use `--force`. Plain apply reports success but changes no files on this class
of project (BUG-1). `--force` runs `apply --accept-no-alignment` repeatedly
until the worktree stops changing. Expect a small number of passes.

## Step 4 — fix compile breaks

Advisor's recipes do not cover every API removal. Fix the rest by hand.
Known breaks after a Boot 3 → 4 upgrade:

| Old code                                            | Fix                                   |
|-----------------------------------------------------|---------------------------------------|
| `kafkaProperties.buildConsumerProperties(sslBundles)` | Call `buildConsumerProperties()` with no argument. Remove the unused `SslBundles` parameter and import. |
| `consumer.buildProperties(null)`                    | Call `buildProperties()` with no argument. |
| `PropertyMapper.get().alwaysApplyingWhenNonNull()`  | Call `PropertyMapper.get()`. Delete the modifier. |
| `map.from(x).whenNonNull().to(...)`                 | Delete `.whenNonNull()`. Non-null filtering is the Boot 4 default. |

Build after each fix: `./mvnw -DskipTests install`.

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
| A dependency stays blocked after auto-mapping      | Gap   | Report it to the framework team.          |

## Report problems to the framework team

Attach: the script output, the newest log in `.advisor/errors/`, your
`.advisor/mappings/` directory, and your root `pom.xml`.
