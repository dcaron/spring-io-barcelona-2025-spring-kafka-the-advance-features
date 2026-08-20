#!/bin/bash
# Repro: `advisor mapping create` resolves coordinate versions WITHOUT the
# project's effective Maven repositories. The pom in this directory declares
# the Confluent repository and depends on io.confluent:kafka-schema-registry-client;
# Maven itself resolves it fine, but advisor reports "No versions found".
# Run from this directory. Requires: advisor CLI on PATH, Maven, network.
set -u
cd "$(dirname "$0")" || exit 1

echo "=== control: Maven resolves the artifact using the pom's repositories ==="
mvn -q -B dependency:resolve -DincludeArtifactIds=kafka-schema-registry-client </dev/null >/dev/null 2>&1
echo "mvn dependency:resolve exit=$? (EXPECT: 0)"

echo
echo "=== advisor mapping create -c=io.confluent:kafka-schema-registry-client ==="
echo "    (EXPECT: '💔 No versions found' although the repo is declared in the pom)"
advisor mapping create -c=io.confluent:kafka-schema-registry-client </dev/null
echo "exit=$?"
ls -la .advisor/mappings/ 2>/dev/null || echo "(no mapping written)"
