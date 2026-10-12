# Follow-up: does advertising `SPRING_ADVISOR_MAPPING_CUSTOM_N_*` during `mapping create` change anything?

**Date:** 2026-08-19 · **Advisor:** 1.6.7 · **Question:** the original experiment
(`../README.md`) ran `mapping create` in bare sandboxes with **no** mapping env vars. Does
running it with the same env vars `upgrade-plan get` sees (and its own mappings dir) change the
slug-collapse / duplicate-slug issues?

**Verdict: no issue changes, but three new behaviors surfaced.**

## Setup

Each run in its own fresh dir (own `.advisor/mappings` output). Two env baselines:

- **Variant A** (`run-one.sh`) — the full upgrade-plan set: indices 0–4 =
  `spring-boot-jackson3` (override), `javafaker`, `avro`, **`apache-kafka`**, `confluent-platform`.
- **Variant B** (`run-b.sh`) — same minus `apache-kafka.json`, plus per-run extra files to
  simulate an accumulating generated-mappings dir.

## Findings

1. **`mapping create` DOES read the env vars** (new). With `apache-kafka.json` wired, any
   request for a coordinate it covers is skipped cleanly, no file written, exit 0:
   *"💔 Project kafka associated to coordinate org.apache.kafka:kafka-group-coordinator already
   exists in current mappings."* (A1 = kafka-group-coordinator, A2 = kafka_2.13,
   A3 = kafka-clients — all skipped.)

2. **The check is requested-coordinate-only — it does not prevent collisions** (B2). With only
   the generated `kafka.json` (coords: kafka-clients, kafka-group-coordinator,
   kafka-server-common) wired, `mapping create -c=…:kafka-metadata` proceeds and emits another
   slug-`kafka` file that again claims `kafka-clients` — same slug AND overlapping coordinate as
   the wired file, no warning. The slug-collapse problem is unchanged.

3. **Generated content is env-independent.** B1/B2/B3/B4 outputs are **byte-identical** to the
   parked no-env `gen-*.json` files (diff -qs). Env wiring changes *whether* a file is generated,
   never *what* is generated. §4.1 also unchanged: kafka_2.13 / connect-api still write the
   hidden empty-slug `.json` (B3, B4), and a wired empty-slug mapping does not stop a second
   empty-slug generation (B4).

4. **`mapping create` uses the STRICT loader — and exposes the duplicate-slug root cause**
   (B5, new, ticket-worthy). Wiring two same-slug files and requesting any covered coordinate
   crashes with an error log (`B5-error-stacktrace.log`):

   ```
   MappingSourceLoadException: Failed to load mapping source '…/kafka.json':
     Error merging mapping source …
   Caused by: java.lang.IllegalArgumentException: Some projects were already defined: [kafka]
   ```

   at `MappingsLoader.buildReport(MappingsLoader.java:90)` ←
   `ProjectService.findByCoordinate` ← `MappingCreateCommand.runCommand(MappingCreateCommand.java:188)`.
   So the 1.6.5-era "Some projects were already defined" merger error is still the root cause in
   1.6.7; `build-config get` merely uses a tolerant path, while `upgrade-plan get` (generic
   message) and `mapping create` (stack trace) share the strict one. This stack trace is the
   evidence the support ticket (§ duplicate-slug defect) lacked.

## Consequence for the workflow

Env-wiring during generation gives a useful **idempotency skip** ("already mapped → don't
regenerate") — worth adopting in `advisor-upgrade.sh`'s auto-mapping loop, since exporting the
env vars *before* generating would stop it from regenerating coordinates already covered by
curated mappings. But it does **not** help the core problem: generated kafka-family mappings
still collapse onto slugs `kafka`/`""`, still can't be co-wired, and the curated
`apache-kafka.json` remains necessary.

## Files

- `A1.log`–`A3.log` — Variant A skips.
- `B1.log`–`B4.log` — Variant B generations (outputs byte-identical to `../gen-*.json`).
- `B5.log`, `B5-error-stacktrace.log` — duplicate-slug loader crash + full stack trace.
- `run-one.sh`, `run-b.sh` — exact repro scripts (paths are session-scratchpad-relative; the
  env-var layout is the part that matters).
