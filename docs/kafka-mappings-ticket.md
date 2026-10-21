# Kafka-related first-party mappings Advisor should ship

Upgrading an ordinary Spring Kafka app (Spring Boot 3.4.5 → 4.0) is blocked because Advisor has no
built-in mappings for the Apache Kafka module family or the Confluent Platform family, and the
per-artifact mappings Advisor generates cannot be composed (the Kafka modules collapse onto shared
project slugs and only one mapping per slug can be wired; Confluent artifacts don't resolve at all
because Advisor ignores the project's `<repositories>`). A hand-curated *consolidated* mapping per
family does work — this repo ships two as reference implementations (see Notes) — but that is
curation users shouldn't have to do. Reproduced on Advisor **1.6.5**; still true on **1.6.7**
(see the status update below).

Please create **two** curated mappings, each modeling the whole train as a **single project keyed
to one version anchor** (not per-artifact files).

## 1. `apache-kafka.json`

Project slug `kafka`, anchored on the `org.apache.kafka:kafka-clients` version (all modules version
in lockstep). Coordinates to cover:

```
org.apache.kafka:kafka-clients
org.apache.kafka:kafka_2.13
org.apache.kafka:kafka-streams
org.apache.kafka:kafka-streams-test-utils
org.apache.kafka:connect-api
org.apache.kafka:connect-json
org.apache.kafka:kafka-group-coordinator
org.apache.kafka:kafka-group-coordinator-api
org.apache.kafka:kafka-metadata
org.apache.kafka:kafka-raft
org.apache.kafka:kafka-server
org.apache.kafka:kafka-server-common
org.apache.kafka:kafka-storage
org.apache.kafka:kafka-storage-api
org.apache.kafka:kafka-tools-api
```

## 2. `confluent-platform.json`

Project slug `confluent`, anchored on the Confluent Platform version (e.g. `7.9.1`), resolved from
the Confluent repo (`https://packages.confluent.io/maven/`). Coordinates to cover:

```
io.confluent:kafka-avro-serializer
io.confluent:kafka-schema-registry-client
io.confluent:kafka-schema-serializer
io.confluent:kafka-protobuf-serializer
io.confluent:kafka-json-schema-serializer
io.confluent:kafka-streams-avro-serde
```

The first three are what this project actually hits; the rest are common siblings worth including.

## Notes for whoever builds these

- Model each as **one project**, not one-per-artifact — per-artifact generation is exactly what
  collides today (on 1.6.5 a `build-config get` hard abort: `RaiseErrorOnDuplicatesCoordinatesMerger`
  → *"Some projects were already defined: [kafka]"*; on 1.6.7 a generic `upgrade-plan get`
  rejection of the second same-slug mapping — see the status update below).
- The Confluent mapping additionally needs coordinate resolution to honor the project's declared
  repositories (see [`advisor-improvements.md`](advisor-improvements.md) §2), or to be shipped
  fully curated so no Confluent repo access is required.
- Reference implementation now shipped in this repo:
  [`.advisor/mappings/apache-kafka.json`](../.advisor/mappings/apache-kafka.json) (slug `kafka`,
  all 15 coordinates above) and
  [`.advisor/mappings/confluent-platform.json`](../.advisor/mappings/confluent-platform.json)
  (slug `confluent`, the 6 `io.confluent:*` coordinates). These consolidated single-project
  mappings replace the earlier per-leaf Kafka mappings, which only covered the leaf artifacts and
  left the internal Kafka modules uncoverable by users.

## Status on Advisor 1.6.7 (verified 2026-08-11)

The ask stands, and 1.6.7 makes it look *more* feasible, not less:

- `mapping create` has improved: sibling grouping has started (e.g. the `kafka-storage` run emits
  4 coordinates), `kafka-clients` now gets its own slug, and — most tellingly — the generated
  per-generation `jackson` requirements are **identical to the curated `apache-kafka.json` table
  for every generation 2.7.x → 4.3.x**. Advisor already computes the data a first-party family
  mapping needs.
- But the output still cannot be composed: 15 per-coordinate runs collapse onto just 3 slugs
  (`kafka` ×9, `kafka-clients` ×1, empty ×5), and `upgrade-plan get` rejects the second mapping
  sharing a slug (only `build-config get` tolerates duplicates). The best duplicate-free
  combination covers 8 of the 15 coordinates; the other 7 modules return to the blocked list.

Full experiment (generated mappings, load-test logs, analysis):
[`.advisor/mappings-generated-1.6.7/README.md`](../.advisor/mappings-generated-1.6.7/README.md);
see also [`advisor-improvements.md`](advisor-improvements.md) §1c and
[`advisor-support-ticket.md`](advisor-support-ticket.md) Defect 3.

**2026-08-20 — split into individually-filable reports with isolated repros.** This ask is now
[`docs/reports/FR-1-first-party-kafka-confluent-mappings.md`](reports/FR-1-first-party-kafka-confluent-mappings.md)
(with a minimal demo project in [`repros/07-no-first-party-kafka-mappings/`](../repros/07-no-first-party-kafka-mappings)
showing 16 blocked coordinates on an ordinary spring-kafka + Schema Registry app), and the
composition problem is
[`docs/reports/FR-2-family-aware-mapping-create-union-merge.md`](reports/FR-2-family-aware-mapping-create-union-merge.md)
(demo: [`repros/08-slug-collapse-family/`](../repros/08-slug-collapse-family)).

## Status on Advisor 1.7.0 (verified 2026-10-12)

Still needed, and the cost of hand-curation showed up concretely:

- The catalog still has nothing for these families: `advisor mapping search --slug` returns *"No
  project found"* for `kafka`, `kafka-clients`, `apache-kafka`, `confluent-platform`, `avro`
  (and `--prefix kafka` finds nothing), while `--slug spring-boot` downloads fine.
- After the Boot 4 / Kafka 4 / Confluent 8 upgrade the module families grew, and every new module
  was an unmapped transitive: `org.apache.kafka:kafka-coordinator-common`, `kafka-share-coordinator`,
  `kafka-transaction-coordinator`, `kafka-test-common-runtime`, `kafka-test-common-internal-api`,
  `io.confluent:kafka-avro-types`, `kafka-schema-types`. On 1.7.0 a single unmapped transitive hides
  the entire plan (BUG-9), so the project reported "No upgrade plan available" until the seven
  coordinates were added by hand to `apache-kafka.json` / `confluent-platform.json` (done in this
  repo and the kit). A first-party family mapping maintained with the release train would not have
  this lag; `mapping update` (new) appends versions but not coordinates.
- Repro 07 on 1.7.0: same 17 coordinates, now reported as *"Missing upgrade mappings: 13 project(s)"*
  (1 direct + 16 transitive), exit 10 (`repros/07-no-first-party-kafka-mappings/transcript-1.7.0.txt`).

## Status on Advisor 1.7.1 (verified 2026-10-21)

Still needed. 1.7.1 is a mappings-only release (release notes published 2026-10-20): it adds ten
Azure SDK for Java mappings, *"a separate mapping for each … because each library needs its own
mapping"*, and its coverage page lists nothing for Apache Kafka, Confluent, Avro or Zookeeper.
`mapping search --slug` returns *"No project found"* for `kafka`, `apache-kafka`, `kafka-clients`,
`confluent`, `confluent-platform`, `avro`, `apache-avro`, `zookeeper`, `apache-zookeeper` (and
`--prefix kafka|conf|avro|zoo` find nothing) while `apache-commons-io` and `azure-core` download
(`docs/reports/evidence-1.7.1/catalog-mapping-search.log`). Kafka **4.4.x** has shipped since
2026-10-12 (visible in repro 04's generated table), so the curated `apache-kafka.json` already needs
its next hand-maintained generation. BUG-9 (one unmapped transitive hides the whole plan) is
unchanged on 1.7.1, and now contradicts the 1.7.0 release note that says only *direct* unmapped
dependencies block the plan — which makes a first-party Kafka family mapping more urgent, not less.
