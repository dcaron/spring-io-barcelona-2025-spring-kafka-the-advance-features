# Open issues in Application Advisor 1.7.2 (Simplified Technical English)

Verified on 2026-11-16 with Advisor 1.7.2, recipes 1.7.7. This list has only the issues that are
open on 1.7.2. Fixed issues and history are not in this list. Each item has the same parts: Problem,
Effect, Workaround, Evidence. The full reports are in this directory.

1. **Forced apply reports success but changes no file** (BUG-1)
   - Problem: `upgrade-plan apply --accept-no-alignment` selects dependencies that are managed by a
     BOM or that are only transitive. It prints "Successfully applied upgrade" and changes no file.
   - Effect: The same step comes back on every run. You cannot tell a real upgrade from a no-op.
   - Workaround: Check `git diff` after each step. The kit stops when a step changes no file.
   - Evidence: `repros/01-apply-noop-loop/probe-force-1.7.2.txt`, `evidence-1.7.2/A-force-run-pass2.log`.

2. **An empty plan gets exit code 0 and no explanation** (BUG-10, now also without a config file)
   - Problem: When blocked upgrades remain but no step is possible, `upgrade-plan get` prints
     "No upgrade plan available" and exits 0. The JSON report says `SUCCEEDED` with `steps: []`.
     This happens when you ignore all restrictions in `.advisor.yml`, and it now also happens with no
     `.advisor.yml` on the small BUG-1 test project.
   - Effect: CI reads exit 0 as "nothing to upgrade". Nobody learns why the plan is empty.
   - Workaround: Do not trust exit 0 alone. Check that `steps` in `target/.advisor/upgrade-plan.json`
     is not empty. The kit does this.
   - Evidence: `evidence-1.7.2/C-ignore-all-probe.log`, `repros/01-apply-noop-loop/transcript-1.7.2.txt`.

3. **A catalog mapping replaces a custom mapping without a message** (new observation)
   - Problem: The 1.7.2 catalog has a mapping `apache-commons-beanutils`. A custom mapping
     `commons-beanutils` for the same coordinate is wired. Advisor uses the catalog mapping and does
     not report the overlap. Advisor detects only mappings with the same slug.
   - Effect: Your custom versions and recipes are not used, and the plan changes shape (see item 2).
   - Workaround: Compare the catalog (`mapping search --prefix`) with your custom mappings on each
     release. Remove custom mappings that the catalog now covers.
   - Evidence: `repros/01-apply-noop-loop/transcript-1.7.2.txt`, `evidence-1.7.2/catalog-slugs-1.7.2.txt`.

4. **`patch apply` deletes a dependency version that the project manages** (BUG-11)
   - Problem: `patch apply` removed the `<dependencyManagement>` entry for `commons-io` 2.16.1 from
     all seven poms. It did not add a new entry. The console and `patch-upgrade.json` do not mention it.
   - Effect: A version decision of the team is lost. On other projects the version conflict comes back.
   - Workaround: After `patch apply`, check `git diff` for removed `<dependency>` elements. Add them
     again. Try `--skip-transitive-deps`.
   - Evidence: `evidence-1.7.2/P-patch-apply-pom-changes.diff`, `evidence-1.7.2/P-patch-upgrade.json`.

5. **Forced apply hangs on a multi-module project with its own rewrite plugin** (BUG-2b, BUG-7)
   - Problem: Advisor runs `process-test-classes` before its own goal. The project's
     `rewrite-maven-plugin` execution then runs with Advisor's `-Drewrite.*` properties and recurses
     in a recipe scan. The Maven process uses up to nine cores and 4.4 GB and does not finish.
   - Effect: The upgrade never completes. The pom is not changed.
   - Workaround: Move the project's `rewrite-maven-plugin` declaration into a profile that is not
     active by default. The kit refuses to run until you do.
   - Evidence: `repros/02-missing-recipe-bundle/hang-evidence-1.7.2.txt`.

6. **The recipe bundle misses a class that the Boot 4 recipes use** (BUG-2a)
   - Problem: Advisor passes seven `com.vmware.tanzu.spring.recipes:*:1.7.7` artifacts and does not pin
     `rewrite-java-dependencies`. If a project plugin brings an old version, the Boot 4 step fails with
     "Recipe class not found: …ModuleHasDependency", exit 30.
   - Effect: The upgrade stops at the Boot 4 step.
   - Workaround: Same as item 5.
   - Evidence: `repros/02-missing-recipe-bundle/variants-1.7.2.txt`.

7. **One transitive dependency without a mapping hides the whole plan** (BUG-9)
   - Problem: With `org.apache.zookeeper:zookeeper` unmapped, `upgrade-plan get` shows no project,
     prints "No upgrade plan available" and exits 10. The JSON report lists 25 hidden projects. The
     release notes say that only direct dependencies block the plan.
   - Effect: You see no plan and no reason on the console.
   - Workaround: Run `upgrade-plan get -f` (or add a mapping). Read `excludedProjects` in the JSON.
   - Evidence: `evidence-1.7.2/A-bug9-probe-no-zookeeper.log`.

8. **Advisor commands handle a duplicate slug differently** (BUG-3, remaining part)
   - Problem: `upgrade-plan get` now rejects the second mapping with a clear message. But
     `build-config get` accepts both files without a message, and `mapping create` crashes with the
     cause only in the error log.
   - Effect: You find the problem late and in a different place for each command.
   - Workaround: Set `merge-strategy` to `OVERRIDE` for the second file, or rename its slug.
   - Evidence: `repros/03-dup-slug-inconsistent-loading/transcript-1.7.2.txt`, `probe-override-1.7.2.txt`.

9. **Version resolution ignores the repositories in the pom** (BUG-5)
   - Problem: `mapping create` queries only Maven Central, `repo.spring.io`, the repositories in
     `settings.xml` and the local repository. It does not use the Confluent repository that the pom
     declares. It reports "No versions found".
   - Effect: You cannot generate mappings for Confluent artifacts.
   - Workaround: Keep the `repositoryUrl` field in the curated `confluent-platform.json`.
   - Evidence: `repros/05-resolution-ignores-repositories/debug-1.7.2.txt`.

10. **An empty custom mapping is skipped without a message** (BUG-6)
    - Problem: A wired mapping file that contains `{}` is ignored. No message names the file.
    - Effect: A damaged mapping goes unnoticed, and its project returns to the blocked list.
    - Workaround: The kit validates each mapping before it wires it.
    - Evidence: `repros/06-empty-mapping-silent-skip/transcript-1.7.2.txt`.

11. **The forced Boot 4 upgrade still needs manual code changes**
    - Problem: After the step to Boot 4.1.2 the build fails at five places:
      `KafkaProperties.buildConsumerProperties(SslBundles)` (three), `Consumer.buildProperties(null)`,
      `PropertyMapper.alwaysApplyingWhenNonNull()`. The recipes also do not change
      `@RetryableTopic(backoff = @Backoff)` to `backOff = @BackOff`.
    - Effect: Each team makes the same six edits by hand.
    - Workaround: Make the edits; the runbook (step 4) lists them.
    - Evidence: `evidence-1.7.2/A-compile-fae.log`, `evidence-1.7.2/A-java-changes-advisor-plus-manual.diff`.

Still missing, not defects: a first-party mapping family for Apache Kafka, Confluent, Avro and
Zookeeper (FR-1; the catalog has 212 slugs and none of these), a family-aware `mapping create`
(FR-2; `kafka_2.13` now gets the slug `org.apache.kafka`, its sibling modules get `kafka`), and a
declared place for custom-mapping wiring (FR-4).

Fixed in 1.7.2 and not in this list: the hidden `.json` file from `mapping create` (BUG-4).
