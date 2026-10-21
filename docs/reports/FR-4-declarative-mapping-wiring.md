# FR-4 — Declarative custom-mapping configuration (replace ordered `SPRING_ADVISOR_MAPPING_CUSTOM_N_*` env vars)

| | |
|---|---|
| Type | Feature request |
| Advisor | 1.6.7 (mechanism unchanged since 1.6.4) |
| Demonstration | every repro that wires mappings, e.g. [`repros/01-apply-noop-loop/run.sh`](../../repros/01-apply-noop-loop/run.sh), [`repros/03-dup-slug-inconsistent-loading/run.sh`](../../repros/03-dup-slug-inconsistent-loading/run.sh) |

## The gap

The only way to wire custom mappings is ordered, index-contiguous environment variables:

```bash
export SPRING_ADVISOR_MAPPING_CUSTOM_0_FILEPATH=.advisor/mappings/spring-boot-jackson3.json
export SPRING_ADVISOR_MAPPING_CUSTOM_0_MERGE_STRATEGY=override
export SPRING_ADVISOR_MAPPING_CUSTOM_1_FILEPATH=.advisor/mappings/javafaker.json
export SPRING_ADVISOR_MAPPING_CUSTOM_2_FILEPATH=.advisor/mappings/avro.json
# … indices must stay contiguous and correctly ordered
```

This is brittle in exactly the ways that bit during this investigation:

- The variables must be re-exported in **every shell** that runs an advisor command; a
  missing export silently produces a *different, degraded plan* (the blocked list returns)
  rather than an error — there is no marker in the output that N custom mappings were(n't)
  loaded.
- Index gaps or reordering silently drop mappings.
- The wiring lives outside the repository, so two developers (or CI vs. laptop) can get
  different plans from the same commit.

## The ask

- **Auto-discovery** of `.advisor/mappings/*.json` (the directory Advisor itself writes
  to), and/or
- a declarative, committable config file:

```yaml
# .advisor/config.yml
customMappings:
  - path: .advisor/mappings/spring-boot-jackson3.json
    merge: override
  - path: .advisor/mappings/avro.json
```

- Either way: every command should **echo which custom mappings it loaded** (count +
  paths), so a missing wiring is visible instead of silently changing the plan.

## Status on Advisor 1.7.0 (re-verified 2026-10-12, recipes 1.7.6)

**Still needed.** The CLI's `--from-yml` reads `.spring-app-advisor.yml` only as the CI opt-in
(`enabled: true`), not as mapping configuration; wiring is still `SPRING_ADVISOR_MAPPING_CUSTOM_N_*`.
`mapping search --slug` downloads catalog mappings into `.advisor/mappings/`, so a declarative
"these slugs + these files" manifest would now have an obvious home.

## Status on Advisor 1.7.1 (re-verified 2026-10-21, recipes 1.7.6)

**Partially addressed by a neighbouring feature.** 1.7.0 (notes published 2026-10-20) introduced a
repository-level `.advisor.yml` (`version: 1`, `upgrade.ignore.<slug>.dependencies/reason`) to ignore
restrictions a mapping declares — verified on 1.7.1
([`evidence-1.7.1/C-ignore-probe-3.advisor.yml`](evidence-1.7.1/C-ignore-probe-3.advisor.yml)) — and
organisation/repository-level *blocked versions*. Custom-mapping wiring is still the ordered
`SPRING_ADVISOR_MAPPING_CUSTOM_N_*` env vars; `.advisor.yml` is the obvious place for a
`mappings:` list and `mapping search --slug` already drops files into `.advisor/mappings/`.
