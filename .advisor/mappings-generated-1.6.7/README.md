# Can `mapping create` (1.6.7) reproduce the curated `apache-kafka.json`? — No.

**Date:** 2026-08-11 · **Advisor:** 1.6.7 · **Question:** now that duplicate slugs no longer
abort (§1c of `docs/advisor-improvements.md`), can generated mappings replace the hand-curated
[`.advisor/mappings/apache-kafka.json`](../mappings/apache-kafka.json)?

Everything here is parked output — nothing in `.advisor/mappings/` was modified. The 15
`gen-*.json` files were produced by running `advisor mapping create -c=org.apache.kafka:<artifact>`
in isolated sandbox directories, one per curated coordinate.

## Verdict

**The data is (nearly) all there, but the files cannot be wired together.** The curated mapping
remains necessary.

### What `mapping create` now gets right (1.6.7)

- **Union coverage is complete:** across the 15 runs, every one of the curated mapping's 15
  `org.apache.kafka:*` coordinates appears at least once. Sibling grouping has improved — e.g.
  the `kafka-storage` run emits 4 coordinates (`kafka-clients`, `kafka-server-common`,
  `kafka-storage`, `kafka-storage-api`).
- **The alignment data matches:** for every generation 2.7.x → 4.3.x the generated
  `jackson` requirement is **identical** to the curated table (2.10.x … 2.21.x); `nextRewrite`
  chains are correct. The generated files are even richer in places (`jackson-annotations`,
  `jakartaee-rest` requirements the curated file lacks). Only 2.4.x–2.6.x are missing, which is
  irrelevant for this project (Kafka 3.8.x/3.9.x).

### Why it still can't reproduce the curated file

The 15 runs collapse onto only **3 slugs**: `kafka` (9 internal-module runs), `kafka-clients`
(1 run), and the **empty slug** `""` (5 runs: `kafka_2.13`, `kafka-streams`,
`kafka-streams-test-utils`, `connect-api`, `connect-json` — §4.1 unchanged, they write a hidden
`.json` file). And:

1. **`upgrade-plan get` still rejects duplicate slugs.** The 1.6.7 duplicate tolerance found in
   §1c applies **only to `build-config get`**. Wiring two mappings with the same slug (whether
   `kafka`+`kafka` or `""`+`""`) makes `upgrade-plan get` fail its *"Validating syntax of upgrade
   mappings"* step on the **second** file: *"Failed to load an additional upgrade mapping from
   '…': Failed to load the mapping source."* (Test A: all 15 wired → fails on the 2nd empty-slug
   file. Test B: only the 9 `kafka`-slug files → fails on the 2nd `kafka` file.) The message now
   names the file — better than 1.6.5's `RaiseErrorOnDuplicatesCoordinatesMerger` abort — but the
   reason is generic and the run still dies.
2. **So at most one file per slug can be wired.** A single empty-slug mapping *does* load fine
   (Test C), and distinct slugs may overlap on a coordinate — `kafka` + `kafka-clients` + `""`
   all claiming `org.apache.kafka:kafka-clients` load and plan successfully (Test D).
3. **The best legal combination covers 8 of 15 coordinates** (Test D:
   `gen-kafka-storage.json` + `gen-kafka-clients.json` + `gen-kafka-streams-test-utils.json`).
   The other 7 modules (`kafka-server`, `kafka-metadata`, `kafka-raft`, `kafka_2.13`,
   `kafka-group-coordinator`, `kafka-group-coordinator-api`, `kafka-tools-api`) return on the
   blocked list — *"Please request your administrator to configure the projects…"* — i.e. the
   original §3 wall is back.

### Doc-worthy deltas vs `docs/advisor-improvements.md` §1c

- The §1c row "duplicate-mapping hard abort → no longer aborts" needs a caveat: **verified
  build-config-only**. `upgrade-plan get` still hard-fails on the second same-slug mapping.
- New in 1.6.7: `kafka-clients` now generates slug `kafka-clients` (its own project), no longer
  colliding with the `kafka` slug family.
- Cross-slug coordinate duplication (same coordinate claimed by different slugs) is tolerated
  end-to-end (merge precedence not investigated).

## Files

- `gen-<artifact>.json` — raw `mapping create` output for `org.apache.kafka:<artifact>`
  (renamed; originals were `kafka.json`, `kafka-clients.json`, or the hidden `.json`).
- `mapping-create-log.txt` — the 15 generation runs.
- `loadtest-A-all-15.log` — all 15 wired alongside the other curated mappings (build-config OK,
  upgrade-plan fails on 2nd empty-slug file).
- `loadtest-B-C.log` — B: 9 `kafka`-slug files only (fails on 2nd); C: single empty-slug file
  (loads, plan OK, 7+ Kafka modules blocked).
- `loadtest-D-cross-slug.log` — 3 distinct slugs overlapping on `kafka-clients` (loads, plan OK,
  7 modules blocked).

Repro of the load tests: wire files via `SPRING_ADVISOR_MAPPING_CUSTOM_N_FILEPATH` (indices 0–3 =
`spring-boot-jackson3` (override), `javafaker`, `avro`, `confluent-platform`; then the files under
test), run `advisor build-config get` + `advisor upgrade-plan get`. `target/.advisor/build-config.json`
was deleted before/after each test; the working tree was left unchanged.
