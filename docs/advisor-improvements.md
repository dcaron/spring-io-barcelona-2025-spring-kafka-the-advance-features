# Spring Application Advisor — improvement recommendations

**Audience:** Broadcom / Tanzu Application Advisor engineering & product
**Advisor version tested:** 1.6.4 (re-verified on 1.6.5 — every blocker below still reproduces; see §4.8)
**Reproducible test case:** this repository (Spring I/O Barcelona 2025 — Spring for Apache Kafka)
**Related artifacts in this repo:** [`advisor.md`](../advisor.md) (the manual attempt),
[`advisor-upgrade.sh`](../advisor-upgrade.sh) (a self-healing driver that works around every
defect below), [`.advisor/mappings/`](../.advisor/mappings) (hand-authored custom mappings).

---

## 1. TL;DR

We tried to fully automate a **Spring Boot 3.4.5 → 4.0** upgrade of a small, ordinary Spring
Kafka application. It cannot be done today — not because of anything unusual in the project,
but because Advisor requires the user to hand-author and hand-wire custom mappings for
**dependencies Advisor should already understand**, and even then two families make it
effectively impossible:

- **`io.confluent:*`** — Advisor's `mapping create` cannot resolve them, **even though the
  project declares the Confluent Maven repository**, because coordinate resolution ignores the
  project's `<repositories>`.
- **Apache Kafka internal modules** (`kafka-server`, `kafka-metadata`, `kafka-raft`, …) — ~13
  transitive artifacts that all belong to one Kafka release train, but Advisor models them as
  separate "projects" that then **collide** on the shared `kafka-clients` coordinate and abort
  the run.

The single biggest theme: **Advisor asks the user to do curation Advisor is better positioned
to do centrally.** The message users see today is literally *"Please request your administrator
to configure the projects…"* — which, for the Kafka module family, is neither reasonable nor
achievable by hand.

### Highest-impact changes

| # | Change | Area | Effort | What the user no longer has to do |
|---|--------|------|--------|-----------------------------------|
| 1 | Resolve coordinates using the **project's own repositories** (pom `<repositories>`, `settings.xml`, mirrors) | `io.confluent:*` | **Quick win** | Nothing — Confluent artifacts "just resolve" |
| 2 | **Ship first-party mappings** for the Apache Kafka module family and the Confluent Platform family | Both | Strategic | Never author/curate Kafka or Confluent mappings |
| 3 | **Validate + skip** empty/invalid custom mappings instead of aborting the whole run | Robustness | Quick win | Debug cryptic "one of the custom mappings is empty" failures |
| 4 | **Union-merge** overlapping mappings instead of `RaiseErrorOnDuplicatesCoordinatesMerger` | Kafka modules | Medium | Manually de-conflict overlapping coordinates |

Everything below expands these with concrete options, ordered *quick win → strategic*.

---

## 2. `io.confluent:*` — artifacts not in Maven Central

### What happens today

The project declares the dependency and the repository it comes from:

```xml
<!-- in 6 application modules -->
<dependency>
  <groupId>io.confluent</groupId>
  <artifactId>kafka-avro-serializer</artifactId>
  <version>${confluent.kafka.version}</version>   <!-- 7.9.1 -->
</dependency>

<repositories>
  <repository>
    <id>confluent</id>
    <url>https://packages.confluent.io/maven/</url>
  </repository>
</repositories>
```

Yet:

```console
$ advisor mapping create -c=io.confluent:kafka-schema-registry-client
💔 No versions found. Please, check if your coordinate is correct and it is
   available in your Maven repositories.
```

`kafka-schema-registry-client` and `kafka-schema-serializer` also arrive transitively through
`kafka-avro-serializer`, and all three end up on the upgrade plan's blocked list.

### Root cause

**`advisor mapping create` (and the plan resolution) do not use the project's effective
repository set.** They look at Maven Central / the local `~/.m2` only. The Confluent repo is
declared *in the poms* (there is no `settings.xml` in this project), so Advisor never sees it —
hence "No versions found" for artifacts that Maven itself resolves without issue.

### Options

**A. Honor the project's effective repositories (quick win — biggest single fix).**
When resolving versions for a coordinate, use the same repository set Maven/Gradle would: the
project's `<repositories>` (including those contributed by active profiles), the user/global
`settings.xml`, and mirror rules. The most robust implementation is to **delegate resolution to
the build tool** (Advisor already shells out to `mvnw`/`gradle` for `build-config`), rather than
reimplementing repository resolution. This fixes Confluent — and any other private/corporate
repository — with **zero user action**.

**B. Explicit repository input + wire the existing `repositoryUrl` field.**
The mapping JSON schema already has a `"repositoryUrl"` field that is currently always `""`.
Add `advisor mapping create -c=… --repository=https://packages.confluent.io/maven/` (repeatable),
persist it into `repositoryUrl`, and use it during resolution. Good fallback for cases where the
repo isn't discoverable from the build (CI, credentials, etc.). Support authenticated repos via
`settings.xml` server credentials.

**C. Ship first-party curated mappings for the Confluent Platform family (strategic).**
Confluent Platform versions track Kafka/Spring generations deterministically (CP 7.x ↔ Kafka
3.x, and the Spring-for-Apache-Kafka matrix is well known). Advisor could maintain and ship
mappings for the common Confluent artifacts (`kafka-avro-serializer`, `kafka-schema-registry-client`,
`kafka-schema-serializer`, `kafka-protobuf-serializer`, `kafka-json-schema-serializer`,
`kafka-streams-avro-serde`, …) keyed to those generations. Users get correct upgrade alignment
with no repository access required at all.

**D. Never emit or silently accept empty mappings (quick win — see also §4).**
When resolution yields nothing, `mapping create` should **fail with a clear, specific cause**
(“could not resolve versions for `io.confluent:…` from repositories [central, confluent]”) and
**not write an empty mapping file**. Today an empty mapping can slip in and poison every later
command (see §4).

---

## 3. Apache Kafka internal modules

### What happens today

The application declares only `spring-kafka` (version managed by the Boot 3.4.5 BOM). That pulls
in a large family of internal Kafka modules transitively. The upgrade plan lists them all as
blocked:

```
Please request your administrator to configure the projects of the
following dependencies:
    - org.apache.kafka:kafka-storage-api
    - org.apache.kafka:kafka-server
    - org.apache.kafka:kafka-server-common
    - org.apache.kafka:kafka-metadata
    - org.apache.kafka:kafka-raft
    - org.apache.kafka:kafka-storage
    - org.apache.kafka:kafka-group-coordinator
    - org.apache.kafka:kafka-group-coordinator-api
    - org.apache.kafka:kafka-tools-api
    - org.apache.kafka:kafka-streams-test-utils
    - org.apache.kafka:kafka_2.13
    …  (~13 modules)
```

Trying to auto-create a mapping for one of them (as [`advisor-upgrade.sh`](../advisor-upgrade.sh)
does) surfaces the real wall:

```console
$ advisor mapping create -c=org.apache.kafka:kafka-group-coordinator
# → writes a mapping with slug "kafka", coordinates including "org.apache.kafka:kafka-clients"

$ advisor build-config get      # after wiring it
java.lang.RuntimeException: Error merging mapping source
  PathMappingSource{filePath=.advisor/mappings/kafka-group-coordinator-api.json}
Caused by: java.lang.IllegalArgumentException: Some projects were already defined: [kafka]
  at ...RaiseErrorOnDuplicatesCoordinatesMerger.merge(...)
```

### Root cause

These modules are **not independent projects** — they are one Apache Kafka release train and
version in **lockstep** with `kafka-clients`. But Advisor:

1. Models each artifact as a project needing its own mapping.
2. Generates each as slug `kafka`, re-claiming the shared `kafka-clients` coordinate.
3. **Rejects** any duplicate project/coordinate across custom mappings
   (`RaiseErrorOnDuplicatesCoordinatesMerger`).

So the very mappings Advisor tells the user to create cannot coexist. This is unsolvable by hand
without collapsing all ~13 modules into a single, carefully de-duplicated mapping — exactly the
work `advisor.md` declines: *"I don't want to take care of all the mappings for the transitive
dependencies."*

### Options

**A. Ship a first-party "Apache Kafka" project mapping (strategic — biggest win).**
Advisor should understand the `org.apache.kafka:*` module family out of the box, as one project
keyed to the `kafka-clients` version, covering `kafka-clients`, `kafka_2.13`, `kafka-streams`,
`connect-*`, and the internal `kafka-server*/kafka-metadata/kafka-raft/kafka-storage*/kafka-group-coordinator*/kafka-tools-api/kafka-streams-test-utils` modules.
`advisor.md` already anticipates this: *"Expectation: covered by Advisor (in the future) since
it's part of start.spring.io dependencies."* Kafka is a first-class Spring Boot starter
ecosystem — it warrants a maintained mapping.

**B. Version-lockstep / BOM-family grouping (medium).**
Even without hand-curated data, Advisor can infer the family: all `org.apache.kafka:*` artifacts
resolved at the **same version** belong to one project (derive the anchor from `kafka-clients`
or the Kafka BOM). Treat them as a unit so no per-artifact mapping is ever required. Generalizes
to any lockstep-versioned module family (Jackson, Spring, Micrometer, …).

**C. Union-merge instead of raise (medium — unblocks user-authored mappings too).**
`RaiseErrorOnDuplicatesCoordinatesMerger` is too strict. Offer a **union/extend merge mode**:
when two mappings reference the same project slug or coordinate, merge their coordinate sets and
rewrite tables rather than aborting. At minimum, auto-dedupe a coordinate already owned by
another project (assign it once, deterministically). This is what lets a user *extend* the
built-in Kafka project with an extra module instead of colliding with it.

**D. Auto-attach transitive-only artifacts to their owning project (medium).**
None of these modules appear in the user's poms — they are purely transitive. Advisor could
attach a transitive artifact to the project of the **direct dependency that pulls it in**
(`spring-kafka` → the Kafka project), so transitive members are covered by the direct
dependency's mapping and never surface as separate blockers.

**E. Family-aware `mapping create` (`--family`).**
`advisor mapping create -c=org.apache.kafka:kafka-clients --family` should emit **one** mapping
covering the whole train with a stable slug, **idempotent** across siblings (creating for
`kafka-metadata` returns the same project, not a conflicting duplicate).

---

## 4. Cross-cutting CLI / UX gaps

These aren't Kafka/Confluent-specific — each one independently lightens the load and made
scripting Advisor unnecessarily hard. (All were hit while building
[`advisor-upgrade.sh`](../advisor-upgrade.sh); the script's comments document each workaround.)

**4.1 Deterministic output path for `mapping create`.**
Today it writes `.advisor/mappings/<slug>.json`, where `<slug>` is Advisor's own project name.
That has two sharp edges:
- An **empty slug** produces a file literally named `.json` (a hidden dotfile).
- A slug can **collide with an existing file** and silently overwrite it — e.g.
  `mapping create -c=org.apache.kafka:kafka-group-coordinator` has slug `kafka`, so it writes a
  `kafka`-slug file that clobbers a committed same-slug mapping (and yields a second `kafka`
  project that then conflicts with the curated `apache-kafka.json` on load).

Add `-o/--output PATH` (and/or print the mapping to stdout) so callers control the destination
and nothing is clobbered.

**4.2 Don't consume stdin.**
`mapping create` reads from stdin, which silently breaks shell loops that pipe data
(`while read … do advisor …; done`). It should read from `/dev/null` unless it genuinely needs
interactive input.

**4.3 Robust custom-mapping loading — validate, name, skip, continue.**
A single empty/invalid custom mapping aborts the **entire** command:

```
com.vmware.tanzu.spring.advisor.exceptions.ControlledException:
  One of the custom mappings provided is empty
```

The message doesn't say **which** file. Advisor should validate each custom mapping on load,
report the offending path, and **skip it and continue** (with a warning) rather than failing the
whole `build-config`/`upgrade-plan`.

**4.4 Declarative config instead of ordered env vars.**
Wiring custom mappings today means:

```bash
export SPRING_ADVISOR_MAPPING_CUSTOM_0_FILEPATH=.advisor/mappings/spring-boot-jackson3.json
export SPRING_ADVISOR_MAPPING_CUSTOM_0_MERGE_STRATEGY=override
export SPRING_ADVISOR_MAPPING_CUSTOM_1_FILEPATH=.advisor/mappings/javafaker.json
export SPRING_ADVISOR_MAPPING_CUSTOM_2_FILEPATH=.advisor/mappings/avro.json
# … indices must stay contiguous and correctly ordered
```

This is brittle, order-sensitive, and easy to get wrong. Prefer **auto-discovery** of
`.advisor/mappings/*.json`, or a declarative `.advisor/config.yml`:

```yaml
customMappings:
  - path: .advisor/mappings/spring-boot-jackson3.json
    merge: override
  - path: .advisor/mappings/avro.json
```

**4.5 Built-in self-heal (`--from-plan` / `--create-missing-mappings`).**
[`advisor-upgrade.sh`](../advisor-upgrade.sh) exists only to loop: read the plan's blocked list →
`mapping create` for each → re-plan → apply. Bake this into the CLI:
`advisor upgrade-plan get --create-missing-mappings` (or `advisor mapping create --from-plan`)
generates every mapping it can, wires them, and re-plans automatically — with the validation and
conflict handling from §2–§3 so it degrades gracefully instead of crashing.

**4.6 Machine-readable output.**
The plan is emitted as tab-indented prose; tooling has to parse *"exactly one leading tab,
`group:artifact`, end-of-line"* to find blocked coordinates. Add `--format=json` exposing
actionable upgrades and blocked dependencies as structured data.

**4.7 Make the blocked message actionable.**
Replace *"Please request your administrator to configure the projects…"* with the concrete next
step: the exact `advisor mapping create` commands to run (or an offer to run them), plus a link
to the custom-upgrades documentation. Ideally, when Advisor knows a family is first-party
(§3A), it shouldn't ask at all.

**4.8 `upgrade-plan apply` hard-requires a commercial recipe even for a no-op upgrade.**
On 1.6.5, applying the *only* actionable upgrade this project has — `micrometer-context-propagation
1.1.x → 1.2.x`, which is **BOM-managed and changes no files** — still forces a download of the
commercial recipe `com.vmware.tanzu.spring.recipes:rewrite-static-analysis:1.7.2` from the
subscription repo (`https://packages.broadcom.com/artifactory/tanzu-maven/`). Without valid
subscription credentials the entire `apply` aborts:

```console
$ advisor upgrade-plan apply
🔎 ProcessFailureException: Command: [ … mvnw site --file …/licenses<random>/pom.xml]
[ERROR] Failed to read artifact descriptor for
        com.vmware.tanzu.spring.recipes:rewrite-static-analysis:jar:1.7.2
[ERROR]   Caused by: … from/to spring-enterprise-subscription (…tanzu-maven/): status code: 401
. You can find the error in .advisor/errors/<ts>.log - Please open a new support ticket …
```

Three separate rough edges compound here:
- **A trivial/no-op upgrade should not need the commercial recipe set at all.** Gate the
  `rewrite-static-analysis` (license-check) step on whether the plan actually rewrites sources;
  skip it for BOM-managed no-ops.
- **The failure is opaque.** It surfaces as a raw Maven `mvnw site` stack trace against a
  generated `license-check` module in a temp `licenses<random>/` directory, ending with *"open a
  support ticket"* rather than *"authenticate to the subscription repo — your token may be
  missing or expired."* The 401 root cause is buried.
- **Scratch is left behind on failure.** Each failed apply leaves a `licenses<random>/` directory
  (and `.advisor/errors/`) in the project root; these are never cleaned up.

Auth mechanics worth documenting for users, too: credentials come from a `<server
id="spring-enterprise-subscription">` in `~/.m2/settings.xml`, and reading them from environment
variables requires the `${env.VAR}` form (plain `${VAR}` resolves only against JVM system
properties, so a `-D` flag or `MAVEN_OPTS` is needed instead). The access token is short-lived
(days), so an expired token presents as exactly this 401 — a common, recurring trip-up.

**4.9 `upgrade-plan apply` loops forever on a transitive-only, version-managed project.**
Once the Kafka + Confluent families are covered (via the curated mappings in
[`.advisor/mappings/apache-kafka.json`](../.advisor/mappings/apache-kafka.json) and
[`confluent-platform.json`](../.advisor/mappings/confluent-platform.json)), the plan is fully
unblocked — advisor discovers **21 projects with nothing blocked**, including the real targets
`spring-boot 3.4.x → 4.1.x`, `spring-kafka 3.3.x → 4.1.x`, `kafka 3.8.x → 4.3.x`,
`confluent 7.9.x → 8.3.x`, and `jackson 2.17.x → 3.1.x`. But **the upgrade still never advances**,
because every `apply` selects the same bottom-of-tree project and does nothing:

```console
$ advisor upgrade-plan apply          # run repeatedly — identical every time
Projects to upgrade:
    * commons-beanutils from 1.9.x to 1.11.x
👍 Successfully applied upgrade.       # …but changed 0 files
```

`commons-beanutils` is **not declared in any pom** — it is purely transitive (pulled via
`commons-validator`, itself only test-data tooling behind `javafaker`). There is no version
declaration anywhere to rewrite, so the apply is a **no-op**; the resolved version stays `1.9.x`,
so the *same* step reappears on the next re-plan. Verified by driving `apply` **six times in a
row**: each returns *"Successfully applied upgrade"*, each re-selects `commons-beanutils`, each
changes nothing, and each deletes + regenerates `build-config.json` only to pick it again — a
stable fixed point. Advisor never reaches `spring-boot`/`spring-kafka`/`jackson`. A trivial,
test-only transitive leaf stalls the entire modernization.

Root cause: `apply` orders bottom-up and treats a transitive/BOM-managed artifact as an actionable
step it can never satisfy, and a no-op apply (no file change, resolved version unchanged) is not
recognized as "cannot progress here." Options:

- **Detect no-progress and don't report success.** If an apply changes no files *and* leaves the
  selected project's resolved version unchanged, treat that project as non-actionable — advance to
  the next candidate, or stop with a clear message (*"no further file-changing steps; N projects
  remain BOM-managed/transitive"*) — instead of looping and printing "Successfully applied."
- **Don't select transitive-only / version-managed artifacts as standalone steps.** A project with
  no direct declaration cannot be upgraded in isolation; cover it via its owning direct dependency
  or BOM (relates to §3D transitive auto-attach) rather than surfacing it as its own apply step.
- **Apply breadth-first / whole-plan.** Apply all actionable projects the plan lists in one pass
  rather than looping one leaf at a time, so a single stuck no-op leaf can't block the
  framework-level upgrades that *do* change files.

This is the one wall left after the Kafka/Confluent mappings — and it is entirely independent of
them.

---

## 5. Prioritized roadmap

| Priority | Recommendation | Effort | Payoff |
|----------|----------------|--------|--------|
| **P0 — quick wins** | 2A Honor project repositories (delegate resolution) | Low | Fixes all private-repo artifacts (Confluent) with zero user action |
| | 4.3 Validate + skip empty/invalid mappings; name the file | Low | Removes a class of cryptic, run-killing failures |
| | 4.1 Deterministic `-o/--output`; never write `.json`/clobber | Low | Safe scripting; no data loss |
| | 4.2 Stop consuming stdin | Trivial | Scriptable |
| | 4.6 `--format=json` plan output | Low–Med | First-class tooling instead of text scraping |
| | 4.8 Skip commercial recipe for no-op upgrades; make the 401 actionable; clean scratch | Low | Trivial upgrades don't need a subscription; clear auth errors; no leftover `licenses*/` dirs |
| | 4.9 Don't loop on no-op/transitive-only apply steps; detect no-progress and advance | Low | The upgrade actually completes instead of stalling forever on a transitive leaf |
| **P1 — medium** | 4.4 Declarative custom-mapping config | Med | Kills brittle ordered env vars |
| | 4.5 Built-in `--from-plan` self-heal | Med | Removes the need for external drivers like `advisor-upgrade.sh` |
| | 3C Union/extend merge (drop hard "raise on duplicates") | Med | Lets users extend built-in projects; unblocks Kafka modules |
| | 3B/3D Lockstep-family grouping + transitive auto-attach | Med | No per-artifact mappings for module families |
| **P2 — strategic** | 3A First-party Apache Kafka family mapping | High | Kafka upgrades work out of the box |
| | 2C First-party Confluent Platform family mappings | High | Confluent upgrades work out of the box |
| | 2B `--repository` flag + `repositoryUrl` wiring | Low–Med | Explicit escape hatch for any private repo |

**Suggested sequence:** land the P0 quick wins first (they turn today's hard failures into
graceful, scriptable behavior and immediately fix Confluent for projects that declare the repo),
then P1 to remove the external-script/env-var burden, then invest in the P2 first-party family
mappings that make Kafka + Confluent upgrades zero-effort.

---

## Appendix — reproduction

This repository is a minimal, faithful reproduction. Environment: Spring Boot **3.4.5**, Java
**21**, `spring-kafka` (BOM-managed), `io.confluent:kafka-avro-serializer` **7.9.1** with the
Confluent repo declared in the module poms, `org.apache.avro:avro` **1.12.0** in the `events`
module. Advisor **1.6.4**.

```bash
# 1. Confluent: fails despite the repo being declared in the poms
advisor mapping create -c=io.confluent:kafka-schema-registry-client
#   → 💔 No versions found. … available in your Maven repositories.

# 2. Kafka internal module: creating a mapping collides with the curated apache-kafka.json (slug "kafka")
advisor mapping create -c=org.apache.kafka:kafka-group-coordinator   # slug "kafka", claims kafka-clients
export SPRING_ADVISOR_MAPPING_CUSTOM_5_FILEPATH=.advisor/mappings/kafka-group-coordinator.json
advisor build-config get
#   → IllegalArgumentException: Some projects were already defined: [kafka]
#     (RaiseErrorOnDuplicatesCoordinatesMerger)

# 3. Empty custom mapping poisons every later call
#   → ControlledException: One of the custom mappings provided is empty
```

For a working end-to-end demonstration of the workarounds (repository-safe generation,
empty-mapping validation, slug-collision protection, duplicate-coordinate skip, and the
plan → create → re-plan → apply loop), see [`advisor-upgrade.sh`](../advisor-upgrade.sh) and the
manual walkthrough in [`advisor.md`](../advisor.md). The remaining blockers after all workarounds
— `io.confluent:*` (unresolvable) and the `org.apache.kafka:*` family (coordinate conflicts) —
are exactly the two areas §2 and §3 propose Advisor handle first-party.
