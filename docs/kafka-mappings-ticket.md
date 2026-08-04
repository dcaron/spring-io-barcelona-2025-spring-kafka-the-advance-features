# Kafka-related first-party mappings Advisor should ship

Upgrading an ordinary Spring Kafka app (Spring Boot 3.4.5 → 4.0) is blocked because Advisor has no
built-in mappings for the Apache Kafka module family or the Confluent Platform family, and users
cannot author them by hand (all Kafka internal modules collapse to one project slug `kafka` and
collide on `org.apache.kafka:kafka-clients`; Confluent artifacts don't resolve at all because
Advisor ignores the project's `<repositories>`). Reproduced on Advisor **1.6.5**.

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
  collides today (`RaiseErrorOnDuplicatesCoordinatesMerger` →
  *"Some projects were already defined: [kafka]"*).
- The Confluent mapping additionally needs coordinate resolution to honor the project's declared
  repositories (see [`advisor-improvements.md`](advisor-improvements.md) §2), or to be shipped
  fully curated so no Confluent repo access is required.
- Reference implementation now shipped in this repo:
  [`.advisor/mappings/apache-kafka.json`](../.advisor/mappings/apache-kafka.json) (slug `kafka`,
  all 15 coordinates above) and
  [`.advisor/mappings/confluent-platform.json`](../.advisor/mappings/confluent-platform.json)
  (slug `confluent`, the 6 `io.confluent:*` coordinates). These consolidated single-project
  mappings replace the earlier per-leaf Kafka mappings, which only covered the leaf artifacts and
  left the ~11 internal modules uncoverable by users.
