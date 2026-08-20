# FR-3 — Machine-readable output for `upgrade-plan get` (`--format=json`)

| | |
|---|---|
| Type | Feature request |
| Advisor | 1.6.7 (flag surface unchanged since 1.6.4) |
| Demonstration | any plan transcript, e.g. [`repros/07-no-first-party-kafka-mappings/transcript.txt`](../../repros/07-no-first-party-kafka-mappings/transcript.txt) |

## The gap

The upgrade plan is emitted only as tab-indented prose mixed with progress spinners:

```
Projects discovered:
	- spring-kafka: 3.3.x → 4.1.x
Please request your administrator to configure the projects of the following dependencies:

	- org.apache.kafka:kafka_2.13
		uses:
			- apache-commons-collections
		blocking upgrades for:
			- spring-boot
	...
Upgrade Plan for your Dependencies:
	- Step 1:
		* Upgrade commons-beanutils from 1.9.x to 1.11.x
```

Tooling that drives Advisor (CI gates, self-healing wrappers like this repo's
`advisor-upgrade.sh`, dashboards) must scrape this text — e.g. "exactly one leading tab,
then `group:artifact`, end of line" to extract blocked coordinates — which silently breaks
whenever the wording or indentation changes (the 1.6.7 output added `uses:`/`blocking
upgrades for:` sub-blocks, which is exactly such a change).

## The ask

`advisor upgrade-plan get --format=json` (and ideally `build-config get` too) exposing as
structured data:

- discovered projects with current/target generations,
- plan steps (ordered) with per-step project upgrades,
- blocked dependencies, each with its owning/using projects and the projects it blocks,
- warnings (version conflicts) and errors.

The data plainly exists — it is all in the prose. A stable JSON contract would remove the
scraping layer entirely and make failures (BUG-1's loop, BUG-3's rejection) detectable by
scripts.
