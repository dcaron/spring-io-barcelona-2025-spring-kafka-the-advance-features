# FR-2 — Family-aware `mapping create` and union-merge for same-slug mappings

| | |
|---|---|
| Type | Feature request |
| Advisor | 1.6.7 |
| Demonstrated | 2026-08-20 |
| Demo | [`repros/08-slug-collapse-family/`](../../repros/08-slug-collapse-family) |
| Related defect | BUG-3 (duplicate-slug rejection mechanics) |

## The gap

`mapping create` for sibling modules of one release train emits mappings that share a slug
and overlap on coordinates — and such mappings cannot be wired together. From the demo
(`transcript.txt`):

```
runs/a/.advisor/mappings/kafka.json -> slug 'kafka',
    coordinates ['kafka-clients', 'kafka-group-coordinator', 'kafka-server-common']
runs/b/.advisor/mappings/kafka.json -> slug 'kafka',
    coordinates ['kafka-clients', 'kafka-metadata']

# wiring both:
Caused by: java.lang.IllegalArgumentException: Some projects were already defined: [kafka]
```

At scale (15 per-coordinate runs across the `org.apache.kafka:*` family, experiment
preserved in `.advisor/mappings-generated-1.6.7/`): the runs collapse onto **3 slugs**
(`kafka` ×9, `kafka-clients` ×1, empty `""` ×5), at most one mapping per slug can be
wired, and the best legal combination covers **8 of 15** coordinates — the other 7 modules
return to the blocked list. So the mappings Advisor tells users to create cannot be
composed into a working plan; only a hand-curated single-file family mapping works.

Two adjacent findings (both verified 2026-08-19/20):

- Wiring existing mappings during generation does **not** help: `mapping create` checks
  only the *requested* coordinate against wired mappings (skipping with *"Project kafka …
  already exists in current mappings"* when covered), but happily generates a colliding
  same-slug file for an uncovered sibling, with no warning.
- The check also creates a catch-22 with the built-in catalog: `mapping create
  -c=commons-collections:commons-collections` refuses (*"Project
  apache-commons-collections … already exists"*) even when that catalog project has **no
  upgrades configured** and is exactly what the plan is blocked on — the user can neither
  use the catalog entry nor replace it.

## The ask

1. **Union-merge same-slug mappings** (coordinates and rewrite tables) instead of
   rejecting the second file — this alone would make today's generated output composable.
2. **Family-aware generation**: `mapping create -c=org.apache.kafka:kafka-clients
   --family` (or by default, when artifacts version in lockstep) should emit **one**
   mapping for the whole train with a stable slug, idempotent across siblings — creating
   for `kafka-metadata` should extend/return the same project, not produce a colliding
   duplicate.
3. **Warn on output collisions**: when generated output shares a slug or coordinate with
   an already-wired mapping, say so at generation time instead of failing later at plan
   time.
4. Allow extending/overriding a catalog project that has no upgrade path, instead of
   refusing with "already exists".
