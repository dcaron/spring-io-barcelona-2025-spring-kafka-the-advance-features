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
