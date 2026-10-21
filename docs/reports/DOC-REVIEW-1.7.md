# Re-reading the Application Advisor 1.7 documentation against our findings (2026-10-21)

Question asked: *are we sure all the defects still apply, and does the documentation describe other
ways to run this upgrade that we have not tried?* Source: every page under
`techdocs.broadcom.com/us/en/vmware-tanzu/spring/application-advisor/1-7/app-advisor/` (73 pages,
all dated 2026-10-20, crawled and read in full, not summarised) plus Broadcom KB 428373. Probes run
the same day on Advisor 1.7.1; evidence in [`evidence-1.7.1/`](evidence-1.7.1/README.md).

## 1. Verdict per defect after the re-read

| Defect | Still applies? | What the docs changed |
|---|---|---|
| BUG-1 apply no-op loop | Yes (default path fixed in 1.7.0; forced path still "success" with 0 files) | `--accept-no-alignment` is documented as *"Not recommended … the code might not compile"*. Nothing about 0-file successes. |
| BUG-2a `rewrite-java-dependencies` missing | Yes | The *"Running commercial recipes"* page gives the manual command with `-Drewrite.recipeArtifactCoordinates=com.vmware.tanzu.spring.recipes:spring-boot-3-upgrade-recipes:1.7.6` only — the same incomplete coordinate set. |
| BUG-2b / BUG-7 project plugin hijack and hang | Yes | No page mentions a project's own `rewrite-maven-plugin`; `--include/--exclude-modules` filter the upgrade, not the lifecycle phase. Untested alternative: the *Tanzu Spring Build Plugins* (Advisor as Maven goals, no CLI) — documented only in the Tanzu Spring docs, not here. |
| BUG-3 duplicate slug | Yes | Docs: *"If the project already exists … the tool rejects the file"* — by design for full mappings; the inconsistency between commands is still undocumented. |
| BUG-4 hidden `.json` | Yes | `mapping search` has a documented `--path` (works; `--help` omits it). `mapping create` has none. |
| BUG-5 pom repositories ignored | **Yes, now provable** | `-d` lists the repositories queried: built-ins, `settings.xml`, local — never the pom's Confluent repository (`repros/05/debug-1.7.1.txt`). |
| BUG-6 empty mapping silent | Yes | — |
| BUG-8 starter pins | Yes, trigger re-scoped | Override semantics are documented: a version block is *"replaced as a whole"*, so our 1.6.x override was invalid; Advisor still should not pin. |
| **BUG-9** unmapped transitive hides plan | **Reduced: documented workaround exists** | `upgrade-plan get/apply -f` *"continues to calculate the upgrade plan when dependencies have no upgrade mappings"*. Verified: `-f` gives the full 25-project plan without the zookeeper mapping; `-f --accept-no-alignment` gives the 24-item step, exit 0. Remaining: default behaviour contradicts the release note, and under `-f` the unmapped coordinate is not *"listed as a warning"* — it vanishes from console and JSON. |
| **BUG-10** ignore-all → empty plan, exit 0 | **Yes, narrower** | Exit 0 follows the documented rule (empty `blockerProjects` is not an exit-code condition). The real blockers are documented *"triangular dependency misalignments"* in this project's own tree (two commons-lang3, three Jackson versions); the documented fix is to resolve them in the poms or use `--accept-no-alignment`. **Re-checked after fixing the conflicts: the exit-0 empty plan reproduces unchanged** (§D2), so the defect stands as filed. |

Feature requests: FR-3 is **closed in practice** (`upgrade-plan.json`, `patch-upgrade.json`, exit
codes, documented CI snippets). FR-4 is **largely closed** (folder, Git and Artifactory mapping
sources — see [`FR-4`](FR-4-declarative-mapping-wiring.md)). FR-1 and FR-2 stand: the catalog
has no Kafka/Confluent/Avro/Zookeeper slugs and *"each library needs its own mapping"* is stated as
the model.

## 2. Ways to run the upgrade that we had not used

Tried on 2026-10-21:

1. **`-f` / `--force` on `get` and `apply`** — plans past unmapped dependencies. This replaces
   half of what the kit's self-healing was for. Kit updated: self-heal first (plain `get` exposes the
   coordinates in `excludedProjects`), then re-plan and apply with `-f` for whatever remains.
2. **Folder-based mapping wiring** — `SPRING_ADVISOR_MAPPING_CUSTOM_0_FILEPATH=.advisor/mappings/`
   loads every `.json` in the folder. Same result as the seven ordered variables.
3. **`.advisor.yml` `upgrade.ignore`** — works per restriction; see BUG-10 for the key semantics and
   where it ends.
4. **Outdated embedded mapping procedure** — `mapping search --slug X --path DIR`, `mapping update`,
   wire `DIR` as `override`. Mechanically fine; for this project the catalog mappings are already
   current, so it changes nothing.

Documented, not tried, and worth knowing:

5. **`upgrade.blocked-versions`** in `.advisor.yml` or a global `blocked-versions.json` — a ceiling
   per slug (e.g. stop before Jackson 3.x or Java 25). The inverse of ignore; useful for staging
   the Jackson 3 move separately from Boot 4.
6. **Git / Artifactory mapping sources** — `SPRING_ADVISOR_MAPPING_CUSTOM_N_GIT_URI` or
   `…_ARTIFACTORY_*` — the central-management model for the kit's curated files.
7. **`--build-tools-latest`**, **`--squash=N`/`--squash-all`**, **`--after-upgrade-cmd`** (formatter
   after apply), **`--build-tool-jvm-args`**.
8. **Skills + MCP server** (`advisor mcp`) — a mapping can reference a zip of agent skills that are
   unpacked into `.claude/skills` after the recipes run; the coding agent completes what recipes
   cannot. The five manual Boot-4 API fixes and the `@RetryableTopic backOff` change are exactly that
   shape of work.
9. **Tanzu Spring Build Plugins** — run Advisor as Maven/Gradle goals without the CLI (Tanzu Spring
   docs). Whether that path shares the BUG-2b lifecycle hijack is unknown.
10. **`--push --from-yml`** with `.advisor.yml` `enabled: true` — the CI pull-request mode.
11. **`patch apply --skip-transitive-deps`** and the `updates:` ignore block in `.advisor.yml`.
12. **`advisor advice list/apply`** — governance/Tanzu extensions, out of scope for the upgrade.

## 3. What this changes in the repository

- Kit: `-f` re-plan/apply when unmapped dependencies remain; the text parser fallback keeps the
  `-f` warning format in case Advisor starts printing it.
- Reports: BUG-5, BUG-8, BUG-9, BUG-10, FR-4 carry a *"Documentation re-read"* section;
  `DEFECTS-STE.md`, `STATUS-1.7.1.md`, the kit's `known-issues.md` and the support ticket are updated
  to the reduced BUG-9 and narrowed BUG-10.
- Support ticket: BUG-9 becomes a documentation/behaviour mismatch with two concrete quotes; BUG-10
  keeps the exit-0 empty-plan ask and drops the "key must be derived from the console" complaint as
  the main point (the `--debug` warning for unknown slugs is documented).

## 4. Open after this review

- Try the Tanzu Spring Build Plugins path on the unguarded worktree (BUG-2b/7 may not apply there).
- ~~Fix the project's own version conflicts and re-run the plain plan~~ — done the same day
  (`STATUS-1.7.1.md` §D): the `events` module lacked the Boot BOM. With one version of every library
  the misalignment warnings are gone; the plain plan is still refused, now only by mapping-backed caps
  (Jackson 2 libraries, the Boot 4.1.1 BOM, validator/beanutils → collections 3.2, and the step-wise
  commons-lang generation match). That is the correct answer for this dependency set.
- Package the manual Boot-4 fixes as a skill and test the MCP flow.
