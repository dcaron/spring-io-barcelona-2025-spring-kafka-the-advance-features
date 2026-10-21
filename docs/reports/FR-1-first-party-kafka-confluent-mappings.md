# FR-1 — Ship first-party mappings for the Apache Kafka module family and the Confluent Platform family

| | |
|---|---|
| Type | Feature request |
| Advisor | 1.6.7 |
| Demonstrated | 2026-08-20, isolated minimal project |
| Demo | [`repros/07-no-first-party-kafka-mappings/`](../../repros/07-no-first-party-kafka-mappings) |
| Reference implementations | [`.advisor/mappings/apache-kafka.json`](../../.advisor/mappings/apache-kafka.json), [`.advisor/mappings/confluent-platform.json`](../../.advisor/mappings/confluent-platform.json) |

## The gap

An entirely ordinary Spring Kafka application — Boot 3.4.5 parent, `spring-kafka` +
`spring-kafka-test` from the Boot BOM, one Confluent serializer — cannot be planned out of
the box. `upgrade-plan get` blocks on **16 coordinates** the user never declared
(`transcript.txt`):

```
Please request your administrator to configure the projects of the following dependencies:
    - org.apache.kafka:kafka_2.13            - org.apache.kafka:kafka-server
    - org.apache.kafka:kafka-server-common   - org.apache.kafka:kafka-metadata
    - org.apache.kafka:kafka-raft            - org.apache.kafka:kafka-storage
    - org.apache.kafka:kafka-storage-api     - org.apache.kafka:kafka-group-coordinator
    - org.apache.kafka:kafka-streams         - org.apache.kafka:kafka-streams-test-utils
    - io.confluent:kafka-avro-serializer     - io.confluent:kafka-schema-registry-client
    - io.confluent:kafka-schema-serializer   - org.apache.avro:avro
    - commons-validator:commons-validator    - commons-beanutils:commons-beanutils
```

…each "blocking upgrades for" `spring-boot`, `spring-kafka`, `spring-framework`,
`jackson`, `micrometer` — i.e. the entire modernization. "Request your administrator" is
not actionable for the Apache Kafka internals: users cannot author these mappings
(generation collapses onto colliding slugs — see FR-2/BUG-3), and they are pulled in by a
first-class Spring Boot starter ecosystem (`spring-kafka` is on start.spring.io).

## The ask

Ship two maintained first-party mappings:

1. **Apache Kafka** — one project (slug `kafka`), anchored on the `kafka-clients` version
   (the whole train versions in lockstep), covering the 15 `org.apache.kafka:*`
   coordinates listed in the reference implementation.
2. **Confluent Platform** — one project (slug `confluent`), anchored on the CP version
   (CP 7.x ↔ Kafka 3.x is deterministic), covering `kafka-avro-serializer`,
   `kafka-schema-registry-client`, `kafka-schema-serializer` and common siblings
   (`kafka-protobuf-serializer`, `kafka-json-schema-serializer`, `kafka-streams-avro-serde`).

Both exist as working hand-curated reference implementations in this repo (linked above);
with them wired, the same project plans 20+ projects with nothing blocked, all the way to
Spring Boot 4. Advisor demonstrably already computes the alignment data: the per-generation
`jackson` requirements that `mapping create` generates for Kafka modules are identical to
the curated table for every generation 2.7.x → 4.3.x.

## Notes

- Model each family as **one project** — per-artifact files are exactly what collides
  today (FR-2, BUG-3).
- The Confluent mapping also needs BUG-5 fixed (or must ship fully curated), since
  `io.confluent:*` cannot currently be resolved by `mapping create` at all.

## Status on Advisor 1.7.0 (re-verified 2026-10-12, recipes 1.7.6)

**Still needed.** `advisor mapping search --slug` for `kafka`, `kafka-clients`, `apache-kafka`,
`confluent-platform`, `avro`, `javafaker` → *"No project found"*; `--prefix kafka` → none
(`spring-boot` resolves, so the catalog lookup works). The demo app (repro 07) now reports
*"Missing upgrade mappings: 13 project(s)"* with the same 17 coordinates split into 1 direct
(tab-indented) + 16 transitive (six-space-indented), exit 10. On the real project at Boot 4.0.8
the family grew: `kafka-coordinator-common`, `kafka-share-coordinator`,
`kafka-transaction-coordinator`, `kafka-test-common-runtime`, `kafka-test-common-internal-api`,
`io.confluent:kafka-avro-types`, `io.confluent:kafka-schema-types` were unmapped until added to
the curated files (done in this repo and the kit, 2026-10-12). A first-party family mapping
would track such module additions; hand-curation does not.

## Status on Advisor 1.7.1 (re-verified 2026-10-21, recipes 1.7.6)

**Still needed.** The 1.7.1 release is a mappings-only update (ten Azure SDK libraries, each as its
own mapping) and its coverage page lists nothing for Apache Kafka, Confluent, Avro, Zookeeper,
javafaker, commons-validator or commons-beanutils. `mapping search --slug` on 1.7.1 returns *"No project
found"* for `kafka`, `apache-kafka`, `kafka-clients`, `confluent`, `confluent-platform`, `avro`,
`apache-avro`, `zookeeper`, `apache-zookeeper`, `javafaker`, `commons-validator`, `commons-beanutils`;
`--prefix kafka|conf|avro|zoo` find nothing; the controls `apache-commons-io` and `azure-core` download
fine ([`evidence-1.7.1/catalog-mapping-search.log`](evidence-1.7.1/catalog-mapping-search.log)).
Repro 07 is identical to 1.7.0 (17 coordinates, exit 10). Meanwhile Kafka **4.4.x** has been released
since the last check (repro 04's generated table now ends at 4.4.x) — one more generation the curated
`apache-kafka.json` has to be taught by hand.
