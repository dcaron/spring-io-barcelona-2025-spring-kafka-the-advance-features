# BUG-11 — `patch apply` deletes a project-managed dependency version and does not report it

| | |
|---|---|
| Advisor | **1.7.2** (recipes 1.7.7), observed 2026-11-16 on `advisor` HEAD (`77fac2c`, Boot 4.1.1) |
| Command | `advisor patch apply` with the project's seven curated mappings wired |
| Evidence | [`evidence-1.7.2/P-patch-apply.log`](evidence-1.7.2/P-patch-apply.log), [`P-patch-apply-pom-changes.diff`](evidence-1.7.2/P-patch-apply-pom-changes.diff), [`P-patch-upgrade.json`](evidence-1.7.2/P-patch-upgrade.json), [`P-build-after-patch.txt`](evidence-1.7.2/P-build-after-patch.txt) |
| Status | New in the 1.7.2 verification; could not be compared with 1.7.1 (the managed entry did not exist in the 1.7.1 patch run's baseline) |

## Summary

Since 2026-10-21 every pom in this reactor manages two versions Spring Boot does not manage:

```xml
<dependencyManagement>
  <dependencies>
    <dependency><groupId>commons-io</groupId><artifactId>commons-io</artifactId><version>2.16.1</version></dependency>
    <dependency><groupId>org.apache.commons</groupId><artifactId>commons-compress</artifactId><version>1.26.2</version></dependency>
    …
```

`advisor patch apply` on 1.7.2 rewrote all seven poms (parent 4.1.1 → 4.1.2, `confluent.kafka.version`
8.3.1 → 8.3.3, 106 transitive pins added) and, in the same edit, **removed the managed `commons-io`
entry from all seven poms**. Nothing replaced it: `commons-io` does not appear among the added
`<dependency>` elements, `target/.advisor/patch-upgrade.json` has no `commons-io` entry among its 108
`patchUpgrades`, and the console summary (*"619 dependency(-ies) upgraded in 7 file(s)"*) says nothing
about a removal. The sibling `commons-compress` entry, written the same way in the same block, was left
alone.

```
-            <dependency>
-                <groupId>commons-io</groupId>
-                <artifactId>commons-io</artifactId>
-                <version>2.16.1</version>
-            </dependency>
+      <dependency>
+        <groupId>com.fasterxml.jackson.core</groupId>
+        <artifactId>jackson-core</artifactId>
+        <version>2.21.8</version>
+      </dependency>
```

In this reactor the effective `commons-io` version happened to stay 2.16.1 in every module after the
patch (the same version arrives transitively), so the build is green and nothing broke. The managed
entry existed precisely to end a *"several versions are used simultaneously"* alignment warning
(`STATUS-1.7.1.md` §D); on a tree where the transitive versions differ, deleting it silently reintroduces
that conflict — and the plain `upgrade-plan get` would then refuse the plan again for a reason the
user had already fixed.

## Expected

- `patch apply` edits versions; it does not delete user-authored `<dependencyManagement>` entries. If a
  pin is judged redundant (same version as the resolved one), leave it, or at least list the removal in
  the console summary and in `patch-upgrade.json` with a reason.
- Treat identical sibling entries identically (`commons-io` was removed, `commons-compress` kept).

## Notes

- Reproduction: `git worktree add ../p 77fac2c`, wire the seven mappings
  (`advisor-kit/mappings/order.txt` + the two generated `commons-*.json`), run `advisor patch apply`,
  then `git diff -- '*/pom.xml' | grep -B3 -A1 '<artifactId>commons-io'`.
- Not tried: `--skip-transitive-deps`, which by the docs leaves dependency-management sections alone and
  may avoid the deletion.
