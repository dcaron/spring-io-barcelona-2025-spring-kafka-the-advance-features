# Release cadence — framework versions, mappings, git, and Maven

This page describes how the moving parts work together over time. Read
`framework-team.md` first for the roles. Read this page for the rhythm.

## The parts

| Part                    | What it holds                                        | System of record | Reaches app teams via        |
|-------------------------|------------------------------------------------------|------------------|------------------------------|
| Internal framework      | Versioned starters, parent poms, libraries           | Framework source repo (git) | Internal Maven repo |
| Internal Maven repo     | Framework jars + proxies (Central, Spring Enterprise, Confluent) | Nexus/Artifactory | Maven resolution (`~/.m2` credentials) |
| The kit                 | Script, curated mapping files, docs, snippets        | Kit repo (git), released by tag | Copy or pull of a kit tag |
| App repos               | Application code + its `.advisor/mappings/` copy     | App repo (git)   | Normal PR flow               |
| Advisor CLI             | The upgrade engine                                   | Vendor download  | Installed per developer / CI |

## Why mappings must track framework versions

Advisor knows the internal framework only through your mapping files. The
catalog has no internal artifacts. When the framework releases version X.Y,
no app can plan an upgrade to X.Y until the mapping file lists X.Y.
Therefore the mapping update is part of the framework release. Ship them
together, in the same cadence.

## Diagram D — systems and flows

```
 FRAMEWORK TEAM                  SHARED INFRASTRUCTURE               APP TEAMS
+-------------------+  release  +-----------------------+  resolve +------------------+
| framework source  |---------->| internal Maven repo   |<---------| app build (mvnw, |
| (git)             |  jars     | (jars + proxies)      |          |  advisor CLI)    |
+-------------------+           +-----------------------+          +------------------+
| advisor-kit       |  tag vN   +-----------------------+  pull vN | app repo (git):  |
| (git)             |---------->| kit repo (git)        |--------->| .advisor/mappings|
+-------------------+           +-----------------------+          |  + upgraded code |
        ^                                                          +------------------+
        |                gap reports (blocked deps, new breaks)             |
        +-------------------------------------------------------------------+
```

## Diagram E — the cadence, step by step

```
framework release X.Y                    (framework team, each release)
  |-- [1] publish the X.Y artifacts to the internal Maven repo
  |-- [2] append X.Y to the framework mapping file; add its recipes
  |-- [3] verify the kit on the reference app (full --force run)
  '-- [4] tag the kit (vN), announce it to the app teams

app upgrade window                       (each app team, own pace)
  |-- [5] pull kit tag vN into the app repo
  |-- [6] run advisor-upgrade.sh --force -y   (resolves via internal repo)
  |-- [7] fix compile breaks; commit sources + .advisor/mappings/
  '-- [8] report gaps to the framework team --> input for kit vN+1
```

Steps 1–4 happen once per framework release. Steps 5–8 happen once per app,
whenever that team schedules the upgrade. The loop closes at step 8.

## Rules of the cadence

1. One kit tag per framework release. The tag states which framework and
   Spring generations it covers.
2. Mapping files are cumulative. Keep the rows for every released version.
   Advisor upgrades one generation per pass, and a lagging app must step
   through old versions to reach the new one.
3. Kit tag vN must upgrade an app from ANY still-supported framework
   version. Verify the oldest supported start version in step 3.
4. App teams never edit curated mapping files. They add app-specific
   mappings at the end of their own `.advisor/mappings/order.txt`.
5. Git pins reproducibility. The `.advisor/mappings/` copy committed with an
   upgrade shows exactly which mapping state produced that change.
6. The internal Maven repo is the only artifact source. `mapping create`
   and `build-config get` resolve through it. A mapping's `repositoryUrl`
   must point to a repository every app team can reach.
7. Advisor CLI updates ride the same train: verify a new CLI version on the
   reference app (step 3) before you announce it.
