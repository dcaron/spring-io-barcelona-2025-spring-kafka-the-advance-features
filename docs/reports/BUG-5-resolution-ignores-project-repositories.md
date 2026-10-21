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

## Status on Advisor 1.7.0 (re-verified 2026-10-12, recipes 1.7.6)

**Unchanged** — Maven resolves the Confluent artifact from the pom-declared repository,
`mapping create` still says *"No versions found. One or more repositories denied access (HTTP
401/403). Check the credentials in ~/.m2/settings.xml."* and exits 0 without a file.
`mapping update` (new in 1.6.7/1.7.0) has the same blind spot: it reports the curated
`confluent-platform.json` "up to date" without being able to query the repository.

## Status on Advisor 1.7.1 (re-verified 2026-10-21, recipes 1.7.6)

**Unchanged** — Maven resolves `io.confluent:kafka-schema-registry-client` through the pom's
repository, `mapping create` still reports *"No versions found. One or more repositories denied access
(HTTP 401/403)…"* and writes nothing (`transcript-1.7.1.txt`).

## Documentation re-read (2026-10-21, techdocs 1.7 pages dated 2026-10-20)

**Confirmed with the new `--debug` output.** The troubleshooting page now documents five distinct
*"No versions found"* messages and says `-d` shows the per-repository status. On 1.7.1 `-d` lists the
repositories Advisor queried for `io.confluent:kafka-schema-registry-client`: Maven Central (built-in,
404), `repo.spring.io/release` (built-in, 401), the `settings.xml` Spring Enterprise repository (401)
and the local repository — **the Confluent repository declared in the pom is not in the list**
(`repros/05-resolution-ignores-repositories/debug-1.7.1.txt`). The message blames credentials because
the built-in repositories answer 401 for an artifact they do not have. The defect stands exactly as
reported: `mapping create` resolves against the CLI's own repository list, not the project's effective
repositories.
