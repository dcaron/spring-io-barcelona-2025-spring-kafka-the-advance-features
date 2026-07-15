Advisor Version: 1.6.4

```bash
advisor build-config get
```

```bash
advisor upgrade-plan get
```

## Build "custom" mappings

### Java Faker 

* https://mvnrepository.com/artifact/com.github.javafaker/javafaker
* ~/.m2/repository/com/github/javafaker/javafaker

```bash
advisor mapping create -c=com.github.javafaker:javafaker
```

### Apache Avro

* https://mvnrepository.com/artifact/org.apache.avro/avro
* ~/.m2/repository/org/apache/avro/avro

```bash
advisor mapping create -c=org.apache.avro:avro
```

### Kafka Streams 

* https://mvnrepository.com/artifact/org.apache.kafka/kafka-streams
* Expectation: covered by Advisor (in the future) since it's part of start.spring.io dependencies)
* ~/.m2/repository/org/apache/kafka/kafka-streams

```bash
advisor mapping create -c=org.apache.kafka:kafka-streams
```

### Kafka / Kafka clients

* https://mvnrepository.com/artifact/org.apache.kafka/kafka-clients
* Expectation covered by Advisor it's transitive dependency of Spring Kafka) 
* ~/.m2/repository/org/apache/kafka/kafka-clients


```bash
advisor mapping create -c=org.apache.kafka:kafka_2.13
```

### Confluent dependencies: Like Confluent Schema Registry

* Not published in Maven Central, but in Confluent Maven repository (https://packages.confluent.io/maven/)
* Failed to build mapping 
* ~/.m2/repository/io/confluent/kafka-schema-registry-client

```bash
advisor mapping create -c=io.confluent:kafka-schema-registry-client
```

Error

```log
💔 No versions found. Please, check if your coordinate is correct and it is available in your Maven repositories.
```

## Example with custom mappings

```bash
export SPRING_ADVISOR_MAPPING_CUSTOM_0_FILEPATH=.advisor/mappings/spring-boot-jackson3.json
export SPRING_ADVISOR_MAPPING_CUSTOM_0_MERGE_STRATEGY=override
export SPRING_ADVISOR_MAPPING_CUSTOM_1_FILEPATH=.advisor/mappings/javafaker.json
export SPRING_ADVISOR_MAPPING_CUSTOM_2_FILEPATH=.advisor/mappings/avro.json
export SPRING_ADVISOR_MAPPING_CUSTOM_3_FILEPATH=.advisor/mappings/kafka.json
export SPRING_ADVISOR_MAPPING_CUSTOM_4_FILEPATH=.advisor/mappings/kafka-streams.json
export SPRING_ADVISOR_MAPPING_CUSTOM_4_MERGE_STRATEGY=override
advisor build-config get
```

```bash
advisor upgrade-plan get
```

I stopped here because I need even more mappings to generate: 

```log
The projects ["", "jackson-annotations", "jackson", "spring-kafka", "spring-boot", "spring-framework", "spring-retry", "micrometer", "junit", "junit-platform", "apache-commons-collections", "micrometer-tracing", "mockito", "xmlunit", "apache-commons-lang", "docker-java", "testcontainers", "avro", "apache-commons-compress", "javafaker"] could not be included in the Upgrade Plan because they are used as transitive dependencies for other projects, and no upgrades are configured for them.
Please request your administrator to configure the projects of the following dependencies:

        - org.apache.kafka:kafka-storage-api
                uses:
                        - 
                        - jackson-annotations
                        - jackson
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - apache-commons-collections
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
                        - 
                        - jackson
                        - avro
                        - apache-commons-compress
        - org.apache.kafka:kafka-server
                uses:
                        - 
                        - jackson-annotations
                        - jackson
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - apache-commons-collections
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
                        - 
                        - jackson
                        - avro
                        - apache-commons-compress
        - io.confluent:kafka-schema-registry-client
                uses:
                        - 
                        - apache-commons-compress
                        - apache-commons-lang
                        - jackson-annotations
                        - jackson
                        - avro
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - apache-commons-collections
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - docker-java
                        - testcontainers
                        - avro
                        - javafaker
                        - apache-commons-compress
                        - 
                        - jackson
        - commons-beanutils:commons-beanutils
                uses:
                        - apache-commons-collections
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - 
                        - micrometer
                        - junit
                        - junit-platform
                        - jackson-annotations
                        - jackson
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
        - io.confluent:kafka-avro-serializer
                uses:
                        - apache-commons-compress
                        - apache-commons-lang
                        - 
                        - jackson-annotations
                        - jackson
                        - avro
                blocking upgrades for:
                        - testcontainers
                        - spring-boot
                        - avro
                        - docker-java
                        - junit
                        - micrometer
                        - spring-framework
                        - mockito
                        - xmlunit
                        - junit-platform
                        - micrometer-tracing
                        - spring-kafka
                        - spring-retry
                        - javafaker
                        - apache-commons-compress
                        - apache-commons-collections
                        - 
                        - jackson
        - commons-validator:commons-validator
                uses:
                        - apache-commons-collections
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - 
                        - micrometer
                        - junit
                        - junit-platform
                        - jackson-annotations
                        - jackson
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
        - io.confluent:kafka-schema-serializer
                uses:
                        - apache-commons-lang
                        - 
                        - apache-commons-compress
                        - jackson-annotations
                        - jackson
                        - avro
                blocking upgrades for:
                        - javafaker
                        - testcontainers
                        - apache-commons-compress
                        - spring-boot
                        - avro
                        - docker-java
                        - junit
                        - micrometer
                        - spring-framework
                        - mockito
                        - xmlunit
                        - junit-platform
                        - micrometer-tracing
                        - spring-kafka
                        - spring-retry
                        - apache-commons-collections
                        - 
                        - jackson
        - org.apache.kafka:kafka-server-common
                uses:
                        - 
                        - jackson-annotations
                        - jackson
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - apache-commons-collections
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
                        - 
                        - jackson
                        - avro
                        - apache-commons-compress
        - org.apache.kafka:kafka-metadata
                uses:
                        - 
                        - jackson-annotations
                        - jackson
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - apache-commons-collections
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
                        - 
                        - jackson
                        - avro
                        - apache-commons-compress
        - org.apache.kafka:kafka-raft
                uses:
                        - 
                        - jackson-annotations
                        - jackson
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - apache-commons-collections
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
                        - 
                        - jackson
                        - avro
                        - apache-commons-compress
        - org.apache.kafka:kafka-streams-test-utils
                uses:
                        - 
                        - jackson-annotations
                        - jackson
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - apache-commons-collections
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
                        - 
                        - jackson
                        - avro
                        - apache-commons-compress
        - org.apache.kafka:kafka_2.13
                uses:
                        - 
                        - jackson-annotations
                        - jackson
                        - apache-commons-collections
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
                        - 
                        - jackson
                        - avro
                        - apache-commons-compress
        - org.apache.kafka:kafka-group-coordinator-api
                uses:
                        - 
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - jackson-annotations
                        - jackson
                        - apache-commons-collections
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
        - org.apache.kafka:kafka-storage
                uses:
                        - 
                        - jackson-annotations
                        - jackson
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - apache-commons-collections
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
                        - 
                        - jackson
                        - avro
                        - apache-commons-compress
        - org.apache.kafka:kafka-group-coordinator
                uses:
                        - 
                        - jackson-annotations
                        - jackson
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - apache-commons-collections
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
                        - 
                        - jackson
                        - avro
                        - apache-commons-compress
        - org.apache.kafka:kafka-tools-api
                uses:
                        - 
                blocking upgrades for:
                        - spring-kafka
                        - spring-boot
                        - spring-framework
                        - spring-retry
                        - micrometer
                        - junit
                        - junit-platform
                        - jackson-annotations
                        - jackson
                        - apache-commons-collections
                        - micrometer-tracing
                        - mockito
                        - xmlunit
                        - apache-commons-lang
                        - docker-java
                        - testcontainers
```

I don't want to take care of all the mappings for the transitive dependencies .
I'm using Spring Kafka here, and I don't have any other Kafka dependencies in my project pom.xml files.


