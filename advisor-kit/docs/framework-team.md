# Framework team — role and tasks

The framework team owns this kit. The team makes Advisor usable for the app
teams and shields them from the known defects.

## You own

- The central mappings repository: the single source of truth for all curated
  mapping files and the default wiring manifest (`order.txt`).
- The kit: script, docs, snippets, and releases of the kit. The kit's
  `mappings/` directory is a snapshot of the central repository, taken at
  each kit release. The kit is the interim distribution channel.
- The pom guard template in `snippets/`.
- Verification of the kit on the reference application.
- Vendor tickets to Broadcom for Advisor defects and feature requests.

## Task table

| Task                        | Trigger                                | Procedure                                            |
|-----------------------------|----------------------------------------|------------------------------------------------------|
| Add or update a mapping     | App team reports a blocked dependency  | Follow the curation rules below                      |
| Verify a new Advisor release| Broadcom publishes release notes       | Run the kit on the reference app; update known-issues|
| Release the kit             | Mappings or script changed             | Follow the release checklist below                   |
| File a vendor ticket        | New defect confirmed with a repro      | Attach logs, mapping files, and the minimal repro    |

## Mapping curation rules

0. Curate in the central mappings repository, through reviewed pull requests.
   Never edit the kit's bundled copies or an app repo's copies directly.
1. Create one mapping file per dependency family.
2. Put all coordinates of the family in that one file, under one slug.
   Example: `apache-kafka.json` holds 15 `org.apache.kafka` coordinates.
3. Add `repositoryUrl` when the artifacts are not on Maven Central.
   Example: `confluent-platform.json` points to `https://packages.confluent.io/maven/`.
4. Do not run `advisor mapping create` per coordinate for family members.
   The outputs collapse onto one slug and cannot be wired together.
5. Never ship an empty mapping file.
6. Use the `override` merge strategy only to patch a catalog project.
7. Check the catalog first: `advisor mapping search --prefix <name>`.
   Ship a curated file only when the catalog has no mapping.

## Kit release checklist

1. Tag the central mappings repository.
2. Copy that tag's mapping files into the kit's `mappings/` (the snapshot).
3. Run the kit on the reference application. Confirm convergence.
4. Sync the reference repo's `.advisor/mappings/` with the kit's `mappings/`.
5. Update `docs/known-issues.md` status columns.
6. Tag the kit. Record the mappings tag it bundles. Announce it to the app teams.

Release the kit in the same cadence as the internal framework. See
`release-cadence.md` for how framework versions, mappings, git, the internal
Maven repo, and the app teams align over time.

## Diagram C — the two-team flow

```
   FRAMEWORK TEAM                          APP TEAMS
  +------------------------+   ships kit  +--------------------------+
  | curate mapping files   |------------->| copy kit into app repo   |
  | own script + snippets  |              | run advisor-upgrade.sh   |
  | verify on ref app      |<-------------| fix compile breaks       |
  +------------------------+  issues,     | validate runtime         |
       |         ^            missing     +--------------------------+
       | tickets | fixes      mappings, logs
       v         |
  +------------------------+
  | VENDOR (Broadcom)      |
  +------------------------+
```

The app teams do not curate mappings. They report gaps to the framework team.
The framework team does not fix application code. It ships the tools.
