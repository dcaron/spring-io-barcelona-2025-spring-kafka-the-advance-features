# Advisor operating model

This page explains how Spring Application Advisor upgrades a repository.
Advisor is a CLI. It reads your build, computes an upgrade plan, and applies
OpenRewrite recipes to your sources.

## The three commands

| Command                    | Input                          | Output                                  |
|----------------------------|--------------------------------|-----------------------------------------|
| `advisor build-config get` | pom.xml, `~/.m2` credentials   | `target/.advisor/build-config.json`     |
| `advisor upgrade-plan get` | build-config, mappings         | The plan: upgrades + blocked list       |
| `advisor upgrade-plan apply` | the plan                     | Edited sources, poms, and config files  |

## Diagram A — the pipeline

```
  pom.xml + ~/.m2 credentials
        |
        v
  +---------------------------+
  | advisor build-config get  |--> target/.advisor/build-config.json
  +---------------------------+
        |
        v
  +---------------------------+    "Projects discovered: X 1.2.x -> 3.4.x"
  | advisor upgrade-plan get  |--> + blocked-transitives list
  +---------------------------+
        |
        v
  +-------------------------------+
  | advisor upgrade-plan apply    |--> OpenRewrite recipes edit sources;
  |   --accept-no-alignment       |    ONE Spring generation per pass
  +-------------------------------+
        |
        +-- plan still actionable? --yes--> loop to upgrade-plan get
        +-- no --> done: fix compile breaks, validate runtime
```

Advisor upgrades one Spring generation per pass. Repeat the loop until an
apply changes no more files. That state is convergence. Use
`--accept-no-alignment` on apply: plain apply does not change files on
projects whose upgrades are all transitive (BUG-1, see `known-issues.md`).

## Custom mappings — why

Advisor knows a project only when a mapping declares it. The built-in catalog
does not contain Apache Kafka, Confluent, or Avro. Without extra mappings,
Advisor blocks the plan and asks you to configure those projects. The kit
ships curated mapping files that fill this gap.

## Custom mappings — how

Wire each mapping file with two environment variables. The index `<N>` starts
at 0 and must be contiguous.

```
SPRING_ADVISOR_MAPPING_CUSTOM_<N>_FILEPATH=.advisor/mappings/<file>.json
SPRING_ADVISOR_MAPPING_CUSTOM_<N>_MERGE_STRATEGY=override   # optional
```

The script derives these variables from `mappings/order.txt`. Do not export
them by hand.

## Diagram B — mapping wiring

```
  Advisor catalog                    Custom files via env vars
  (built-in projects)                SPRING_ADVISOR_MAPPING_CUSTOM_<N>_FILEPATH
  +------------------+               +--------------------------------------+
  | spring-boot  <---+--override-----| 0 spring-boot-jackson3.json          |
  | spring-kafka     |               | 1 javafaker.json                     |
  | micrometer ...   |               | 2 avro.json                          |
  | (NO kafka /      |               | 3 apache-kafka.json      (15 coords) |
  |  confluent /     |               | 4 confluent-platform.json (6 coords  |
  |  avro)           |               |     + repositoryUrl)                 |
  +------------------+               +--------------------------------------+
           \                                  /
            v                                v
           +----------------------------------+
           | merged project set               |
           | consumed by upgrade-plan         |
           +----------------------------------+
```

Rules:

1. Indices are contiguous and start at 0. A gap hides all later mappings.
2. One dependency family = one file = one slug. Two files with the same slug
   crash the plan ("Some projects were already defined").
3. Never wire an empty mapping. An empty file breaks every Advisor call.
4. Use `MERGE_STRATEGY=override` only to patch a project that the catalog
   already contains (example: `spring-boot-jackson3.json`).
