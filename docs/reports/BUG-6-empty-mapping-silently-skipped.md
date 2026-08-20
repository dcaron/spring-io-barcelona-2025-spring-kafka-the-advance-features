# BUG-6 — An empty custom mapping is skipped silently (no warning naming the file)

| | |
|---|---|
| Type | Defect / UX |
| Advisor | 1.6.7 |
| Verified | 2026-08-20 |
| Repro | [`repros/06-empty-mapping-silent-skip/`](../../repros/06-empty-mapping-silent-skip) (one `{}` fixture + minimal pom) |

## Summary

On 1.6.5 a single empty/invalid custom mapping aborted every command with
*"One of the custom mappings provided is empty"* (without naming the file). 1.6.7 fixed
the abort — but over-corrected: a wired `{}` mapping is now ignored **with no output at
all**. The command succeeds and nothing ever mentions the file:

```console
$ export SPRING_ADVISOR_MAPPING_CUSTOM_0_FILEPATH=$PWD/mappings/empty.json   # contains {}
$ advisor build-config get
🚀 The build-configuration has been generated in .../build-config.json       # no warning
```

(`transcript.txt`: the string `empty.json` appears nowhere in Advisor's output.)

## Why it matters

`mapping create` can and does produce empty/near-empty mappings when resolution fails
(see BUG-5), and scripted pipelines wire whatever files exist. A truncated, typo'd or
empty mapping now fails **silently**: the affected project simply reappears on the blocked
list ("Please request your administrator to configure…") with no hint that a wired mapping
file was dropped.

## Expected

Validate each custom mapping at load time and emit a warning that names the skipped file
and the reason (`"skipping custom mapping .../empty.json: empty mapping"`), then continue.
Skip-and-continue is the right behavior — it just must be observable.
