# BUG-10 — with every blocker ignored via `.advisor.yml`, the plan is empty, says nothing, and exits 0 (1.7.1)

| | |
|---|---|
| Type | Defect (planning / exit codes / JSON report) |
| Advisor | **1.7.1** (feature introduced in 1.7.0: `.advisor.yml` `upgrade.ignore`) |
| Verified | 2026-10-21, original repo at Boot 4.1.1 (`advisor` branch HEAD `5fbf01a`, worktree `adv171-C`, 7 curated mappings wired) |
| Evidence | [`evidence-1.7.1/C-ignore-probe.log`](evidence-1.7.1/C-ignore-probe.log) → [`C-ignore-probe-2.log`](evidence-1.7.1/C-ignore-probe-2.log) → [`C-ignore-probe-3.log`](evidence-1.7.1/C-ignore-probe-3.log) + [`C-ignore-probe-3.advisor.yml`](evidence-1.7.1/C-ignore-probe-3.advisor.yml), [`C-ignore-probe-3b-flags.log`](evidence-1.7.1/C-ignore-probe-3b-flags.log) |

## Summary

The 1.7.0 release notes add *"Ignore a project restriction that blocks an upgrade"*: an
`upgrade.ignore` section in a repository-level `.advisor.yml`, keyed by *"the mapping slug of the
project whose restriction you want to ignore"*. On this project the plain plan is refused with seven
blockers (exit 50), e.g. *"jackson:2.17.x needs an upgrade or migration defined in the upgrade mappings
to upgrade jackson-annotations > 2.17.x"* and *"apache-commons-lang:3.20.x needs an upgrade … to
upgrade apache-commons-io > 2.15.x"*.

Three probes:

1. Keys = the slugs named first in the blocker lines (`jackson`, `commons-beanutils`,
   `commons-validator`, `confluent`, `spring-boot`, `apache-commons-lang`), `dependencies: "*"`:
   five of seven blockers disappear; the two `apache-commons-lang` ones stay. Exit 50.
2. Keys = the *restricted* projects (`apache-commons-io`, `apache-commons-compress` with
   `dependencies: [apache-commons-lang]`, plus `apache-commons-collections`, `jackson-annotations`,
   `xmlunit` with `"*"`): the two `apache-commons-lang` blockers disappear, the other five come back.
   So the key is the slug whose **mapping declares** the restriction — `jackson`'s mapping pins
   `jackson-annotations`, but `apache-commons-io`'s mapping declares its `apache-commons-lang`
   requirement (the JSON shows the asymmetry: `lastSupportedVersion` vs `nextSupportingVersion`).
   The docs sentence is right, the console blocker lines point the wrong way for half of them.
3. Union of both keyings (the `.advisor.yml` in the evidence): **every blocker is gone** and the
   output is

   ```
   Projects discovered: … 8 projects with an arrow …
   No upgrade plan available.
   ⚠️  Warnings: … (alignment conflicts only)
   Upgrade Plan was calculated with ignored restrictions.
   exit=0
   ```

   `target/.advisor/upgrade-plan.json`: `executionMetadata {"exitCode": 0, "status": "SUCCEEDED"}`,
   `steps: []`, and **eight `blockedUpgrades` entries whose `blockerProjects` are empty** — blocked
   by nothing, planned as nothing, reported as success. `-f` and `--squash-all` give the same;
   only `--accept-no-alignment` produces the one-step plan (the same eight upgrades), i.e. what still
   holds the plan back is the *"several versions are used simultaneously"* alignment state, which the
   console never says and which the exit-code table maps to no code.

## Why it matters

- The new feature is the documented way to unblock a plan without touching mappings. Followed to the
  end, it yields a success exit code and an empty plan: a CI pipeline branching on exit codes (the
  stated purpose of the 1.7.0 exit-code work) would conclude "nothing to upgrade" on a project with
  eight pending upgrades.
- A `blockedUpgrades` entry with no blocker is self-contradictory; the report is the thing automation
  is supposed to read.
- The blocker summary names the wrong slug for restrictions of the `nextSupportingVersion` kind, so
  users cannot derive the ignore key from the console output.

## Expected

- If the remaining obstacle is alignment, say so (*"plan withheld: dependency conflicts — rerun with
  `--accept-no-alignment` or resolve …"*) and exit **50** (or a dedicated code); never 0 with no plan.
- `blockedUpgrades[].blockerProjects` must name what blocks, or the entry must not be there.
- Print the ignore key with each blocker line (*"ignore with `upgrade.ignore.apache-commons-io`"*).

## Documentation re-read (2026-10-21, techdocs 1.7 pages dated 2026-10-20)

**Still a defect, narrower than first written.** Three things the docs settle:

- `blockedUpgrades[].blockerProjects` is documented as *"Empty when the project needs a migration that
  the upgrade mappings do not define"*, and exit 50 is defined only for *"a blocked upgrade with a
  non-empty `blockerProjects` list"*. So exit 0 with eight blocker-less entries follows the documented
  rules; what is wrong is the state itself — eight upgrades with a defined next version are reported
  as needing an undefined migration, with no console line — and that the CI guidance says exit 0 must
  mean *"nothing to upgrade"*.
- The blockers themselves are mostly what the docs call a **triangular dependency misalignment**
  (*"two different versions of a particular project dependency used by two different projects"*): the
  warnings *"several versions are used simultaneously"* name commons-lang3 3.14.0 + 3.20.0, jackson
  2.17 + 2.21 + 3.1, commons-io 2.15 + 2.16 in this project's tree. The documented actions are to fix
  the application's dependency conflict (exclude or upgrade the odd version) or to use
  `--accept-no-alignment`; `upgrade.ignore` is documented for mapping-declared restrictions, which is
  only part of what blocks here. The documented *"outdated embedded mapping"* procedure
  (`mapping search --slug` → `mapping update` → wire as `override`) was tried for `apache-commons-io`
  and `apache-commons-compress`: both catalog mappings are *"up to date"* and the override changes
  nothing ([`evidence-1.7.1/C-folder-mode-and-outdated-mapping-probe.log`](evidence-1.7.1/C-folder-mode-and-outdated-mapping-probe.log)).
- Unknown slugs in `upgrade.ignore` are reported only with `--debug`, which is why probe 1 and 2
  failed silently for half the keys.

Revised ask: when ignored restrictions leave only alignment conflicts, print that and exit 50 (or a
new code), and name the ignore key in each blocker line. Kit: the plain plan on this repo needs the
dependency conflicts fixed in the poms, not more ignore keys.
