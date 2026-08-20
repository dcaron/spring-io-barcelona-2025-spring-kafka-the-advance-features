# BUG-5 — `mapping create` ignores the project's `<repositories>` and misdiagnoses the failure as a credential problem

| | |
|---|---|
| Type | Defect |
| Advisor | 1.6.7 |
| Verified | 2026-08-20 |
| Repro | [`repros/05-resolution-ignores-repositories/`](../../repros/05-resolution-ignores-repositories) (one pom + one command) |

## Summary

`advisor mapping create -c=<coordinate>` resolves versions without consulting the
project's effective Maven repository set. A pom that declares the (public,
unauthenticated) Confluent repository and depends on
`io.confluent:kafka-schema-registry-client:7.9.1` resolves fine with Maven, but Advisor
reports no versions — and on 1.6.7 the message actively **misdiagnoses the cause as bad
credentials**:

```console
$ mvn dependency:resolve         # exit 0 — Maven resolves it via the pom's repo

$ advisor mapping create -c=io.confluent:kafka-schema-registry-client
💔 No versions found. One or more repositories denied access (HTTP 401/403).
   Check the credentials in ~/.m2/settings.xml.
```

The credentials in `~/.m2/settings.xml` are valid (subscription downloads work in the same
session); the 401/403 comes from whatever repositories Advisor *did* probe. The actual
problem — the pom-declared `https://packages.confluent.io/maven/` is never consulted — is
not mentioned, sending users down a credentials rabbit hole.

## Reproduction

`run.sh` in the repro directory; full capture in `transcript.txt`. The pom is 35 lines:
one dependency, one `<repositories>` entry.

## Expected

- Resolve coordinates with the same effective repository set the build itself uses
  (project `<repositories>` incl. active profiles, `settings.xml`, mirrors) — most
  robustly by delegating resolution to the build tool Advisor already shells out to.
- Alternatively/additionally: a repeatable `--repository=<url>` flag, persisted into the
  mapping's existing (currently always-empty) `repositoryUrl` field.
- When resolution fails, name the repositories actually consulted, so "you never looked at
  the repo my pom declares" is visible instead of implying a credential problem.

## Impact

Every artifact family hosted outside Maven Central (Confluent, corporate Nexus/Artifactory
without mirror config) is un-mappable via `mapping create`, and the plan blocks on those
artifacts (see FR-1's demo where all `io.confluent:*` artifacts land on the blocked list).
