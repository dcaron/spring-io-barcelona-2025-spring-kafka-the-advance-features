# Framework team — role and tasks

The framework team owns this kit. The team makes Advisor usable for the app
teams and shields them from the known defects.

## You own

- The kit: script, docs, snippets, and releases of the kit.
- The curated mapping files in `mappings/` and the manifest `mappings/order.txt`.
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

1. Run the kit on the reference application. Confirm convergence.
2. Sync the reference repo's `.advisor/mappings/` with the kit's `mappings/`.
3. Update `docs/known-issues.md` status columns.
4. Tag or version the kit directory. Announce the change to the app teams.

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
