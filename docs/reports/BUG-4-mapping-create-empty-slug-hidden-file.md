# BUG-4 — `mapping create` writes a hidden `.json` file for empty slugs; no `-o/--output`; silent clobber

| | |
|---|---|
| Type | Defect / UX |
| Advisor | 1.6.7 |
| Verified | 2026-08-20 |
| Repro | [`repros/04-empty-slug-hidden-file/`](../../repros/04-empty-slug-hidden-file) (one command, empty directory) |

## Summary

`mapping create` derives its output filename from the project slug it computed itself
(`.advisor/mappings/<slug>.json`). Three sharp edges:

1. **Empty slug → hidden dotfile.** For several real artifacts the computed slug is the
   empty string, so the mapping is written to a file literally named **`.json`** — hidden
   by default, and impossible to distinguish from a second empty-slug mapping (the next
   empty-slug generation overwrites it).
2. **Slug collisions silently overwrite.** A generated slug that matches an existing file
   (e.g. slug `kafka` colliding with a committed curated `kafka.json`) clobbers it without
   warning.
3. **No `-o/--output`** (and no print-to-stdout), so callers cannot control the
   destination.

## Reproduction (`run.sh`, capture in `transcript.txt`)

```console
$ advisor mapping create -c=org.apache.kafka:kafka_2.13
🚀 Created 1 mapping file(s) at: .../.advisor/mappings

$ ls -la .advisor/mappings/
-rw-r--r--  1 ... 4884 ... .json          ← hidden file

$ python3 -c "import json; print(repr(json.load(open('.advisor/mappings/.json'))['slug']))"
''
```

Other coordinates producing the empty slug in our testing: `org.apache.kafka:kafka-streams`,
`kafka-streams-test-utils`, `connect-api`, `connect-json` (5 of the 15 Kafka-family
coordinates tested).

## Expected

- Never write a hidden/empty-named file — an empty slug should be an error or fall back to
  a coordinate-derived filename.
- Refuse to overwrite an existing file unless `--force`.
- Add `-o/--output PATH` (or `--stdout`) so scripts control the destination.
