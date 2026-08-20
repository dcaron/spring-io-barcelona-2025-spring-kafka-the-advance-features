#!/bin/bash
# Demonstration for the feature request "ship first-party Apache Kafka and
# Confluent Platform mappings": an ordinary Spring Kafka + Schema Registry app
# (spring-kafka via the Boot BOM, one Confluent serializer) cannot be planned
# out of the box — Advisor blocks on the transitive Apache Kafka module family
# and the io.confluent artifacts, telling the user to "request your
# administrator to configure the projects".
# Run from this directory. Requires: advisor CLI on PATH, Maven, network.
set -u
cd "$(dirname "$0")" || exit 1
rm -rf target

echo "=== upgrade-plan get, NO custom mappings wired ==="
echo "    (EXPECT: blocked list naming org.apache.kafka:* internals and io.confluent:*)"
advisor upgrade-plan get </dev/null
echo "exit=$?"
