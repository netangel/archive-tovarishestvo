# Architecture Review

**Date:** 2026-09-01
**Scope:** Full repository (~5,650 lines PowerShell), commit `708315d`
**Verdict:** Sound macro-architecture; the problems are one level down — implicit module coupling and error handling that conflates "nothing to do" with "broken".

## Overview

The system has two planes, with the metadata Git repository as the seam between them:

```
Plane A — operator workstation (Windows scan-PC)
  Complete-ArchiveProcess.ps1
    → Test-EnvironmentConfiguration.ps1   (JSON over stdout)
    → Sync-MetadataGitRepo.ps1            (subprocess)
    → Convert-ScannedFIles.ps1            (subprocess)  ── binaries → SMB share
    → Submit-MetadataToRemote.ps1         (subprocess)  ── JSON → git branch
    → New-GitServerMergeRequest           (in-process)

               ↓  human reviews & merges the MR

Plane B — CI in the metadata repo (Gitea Actions / GitLab CI)
  ConvertTo-ZolaContent.ps1 → zola build → aws s3 sync
```

Using Git as both the queue and the human review gate between an untrusted batch job and a public deploy is the right call for this problem: versioned metadata, diffable changes, rollback, and an approval step for free. This should not change.

## Strengths

- **Provider abstraction** (`libs/GitServerProvider.psm1`) — base class, two implementations, factory with `ValidateSet`. Adding Forgejo or GitHub is a ~60-line class plus one `switch` arm.
- **Content generation is a pure function of the metadata.** `ConvertTo-ZolaContent.ps1` reads JSON and writes Markdown, nothing else. Re-runs identically anywhere.
- **Index key design** — MD5 of `|dir|filename|` (`libs/HashHelper.psm1:41`) is stable and path-safe, and decouples the metadata key from the transliterated filename so renames do not orphan records.
- **Test coverage is above average for a PowerShell project** — ~1,900 lines of Pester including real-tool E2E tests with Cyrillic fixtures.
- **Transliteration handles combining diacritics** (`libs/ConvertText.psm1:147-152`).

## Extensibility — 4/10

The libraries look modular but are not.

- **`libs/ScanFileHelper.psm1` imports only `ToolsHelper` yet calls into three other modules.** Verified: imported in isolation, `ConvertTo-Translit`, `Get-TagsFromName`, `Get-ThumbnailFileName` and `Convert-PdfToTiff` all fail to resolve. It works in production only because `Convert-ScannedFIles.ps1:16-22` imports everything into global scope first. The same applies to `$MetadataDir`, read at `Convert-ScannedFIles.ps1:31` and `libs/JsonHelper.psm1:19` via global fallback.
- **Wrong seams.** `Get-TagsFromName` / `Get-YearFromFilename` — the volatile domain heuristics, documented by 17 KB of `TagProcessingLogic.md` — live inside `PathHelper.psm1`, a path-utility module.
- **Hardcoded variation points.** Thumbnail sizes `@(400)` (`ScanFileHelper.psm1:42,79`), target branch `"main"` (`Complete-ArchiveProcess.ps1:122`, `GitHelper.psm1:140`), `$staticDirs = @('about','contact')` (`ConvertTo-ZolaContent.ps1:36`), DPI/quality/resize (`ConvertImage.psm1:22,52`).
- **TOML written by string concatenation** (`ZolaContentHelper.psm1:26-118`), with no escaping. A title containing `"` emits invalid TOML and fails the entire `zola build`. Windows filename rules currently prevent this from firing via filenames, so it is a landmine rather than a live bug — but the free-text `Description` field is unprotected.
- **Dead code.** `Create-MergeRequest.ps1` (85 lines) duplicates `GitLabProvider` and is called by nothing. `Test-CreateMR.ps1` calls `New-GitLabMergeRequest`, which carries a hardcoded GitLab project ID (`GitHelper.psm1:236`). `Test-RequiredTools` / `Install-RequiredTools` are unused and call `Read-Host` inside a validation path.
- **The orchestrator's only inter-stage contract is a subprocess exit code**, which caps how the pipeline can grow.

## Fault Tolerance — 3/10

Confirmed defects, in severity order:

| # | Finding | Location |
|---|---------|----------|
| 1 | **The orchestrator's JSON handoff is broken.** `ConvertTo-Json` emits 9 line objects; the filter keeps only `{`, and the parse dies. The main entry point cannot get past validation. Nothing in `tests/` covers this script. | `Complete-ArchiveProcess.ps1:37` |
| 2 | **The API connectivity check can never fail.** Both `TestOpenMergeRequests` implementations swallow their exceptions and `return $false`, so the caller's try/catch is dead. An expired token passes validation. | `Test-EnvironmentConfiguration.ps1:245-249`, `GitServerProvider.psm1:59-63,152-156` |
| 3 | **A no-op run reports failure.** `git commit` exits 1 when there is nothing to commit, which propagates as *"Не получилось создать и отправить список изменений"* on a successful run where nothing changed. | `GitHelper.psm1:178` |
| 4 | **`exit 1` inside a library** terminates the host process from module code. No caller can catch, retry, or clean up — which is why `Sync-MetadataGitRepo.ps1`'s try/catch is decorative. | `GitHelper.psm1:83` |
| 5 | **Empty catch block** (placeholder comment still in place). Any non-git exception is swallowed and the script exits 0, reporting a successful push. | `Submit-MetadataToRemote.ps1:32-34` |
| 6 | **No transactionality.** The index is written only after a whole directory is processed. On retry, cached metadata is trusted without checking that the PNG exists — so a crash between TIF and PNG creation yields metadata pointing at a file that was never made. | `Convert-ScannedFIles.ps1:102`, `ScanFileHelper.psm1:59` |
| 7 | **Two config keys must agree, enforced nowhere.** The converter writes to `$ResultPath/metadata`; Git commits `config.MetadataPath`. Divergence surfaces as the misleading failure in #3. | `Convert-ScannedFIles.ps1:31`, `Complete-ArchiveProcess.ps1:43` |
| 8 | **Delete-then-generate.** Recursive force-delete of everything outside a two-element allowlist runs *before* any content is written. | `ConvertTo-ZolaContent.ps1:39-46` |
| 9 | **Zero retries or timeouts** on any `Invoke-RestMethod`, `git ls-remote`/`pull`/`push`, or SMB operation. | throughout |
| 10 | **No integrity check between planes.** Metadata ships via Git+CI; images ship to S3 out-of-band (CI runs `--exclude "media/*"`). Nothing verifies that a merged MR's referenced images exist at their destination. | `integrations/gitea/build-and-deploy.yaml` |

Smaller items: `TrimEnd('.git')` is a char-set trim, not a suffix trim (`.../digit` → `.../d`) and does not normalize scp-style SSH URLs against `ssh://` URLs (`GitHelper.psm1:119`); `git add *` is a glob, not `-A` (`:170`); the commit message embeds literal quote characters (`:178`); `$_.Exception.Response | ConvertFrom-Json` parses an `HttpResponseMessage` as JSON and always fails (`GitServerProvider.psm1:99`) — the Gitea sibling at `:193` does it correctly.

## Recommended Improvements

All items below are behavior-preserving.

### Tier 1 — correctness, small diffs

1. Fix the stdout JSON handoff — join the captured lines into a single string before `ConvertFrom-Json`, or emit the JSON with `-Compress`; better still, pass a temp file path instead of scraping stdout.
2. Make `TestOpenMergeRequests` rethrow, or add a dedicated `TestConnection()` that does.
3. Check `git status --porcelain` before committing; treat a clean tree as success, not failure.
4. Replace `exit 1` in `Invoke-GitOperation` with `throw`; let entry scripts own the exit code. Fill in the empty catch.
5. Assert in `Test-EnvironmentConfiguration.ps1` that `$ResultPath/metadata` and `config.MetadataPath` resolve to the same directory.
6. Replace both `TrimEnd('.git')` sites with a real URL normalizer that handles scp-style SSH.

### Tier 2 — structural

7. **Make module dependencies explicit** — every `.psm1` imports what it calls. Add a Pester test that imports each module alone and asserts its exports resolve.
8. **Convert `libs/` into one module with a `.psd1` manifest** (`NestedModules` / `RequiredModules`). Removes load-order fragility and the `$MetadataDir` global.
9. **Extract `TagHelper.psm1`** for `Get-TagsFromName` / `Get-YearFromFilename`; `TagProcessingLogic.md` becomes its documentation.
10. **Route all TOML through one escaper.** Better: build a hashtable per page and serialize once, so adding a field is a dictionary entry rather than a heredoc edit.
11. **Atomic index writes** — write `foo.json.tmp`, then `Move-Item -Force`.
12. **Verify before trusting** — `Test-Path` the PNG and thumbnail before reusing cached metadata.
13. **Hoist magic constants** into `config.json`: `ThumbnailSizes`, `TargetBranch`, `StaticContentDirs`, `Dpi`, `Quality` — seeded with today's values.

### Tier 3 — larger

14. **Test the orchestrator.** The highest-value gap: nothing covers `Complete-ArchiveProcess.ps1`, which is exactly where the confirmed break lives.
15. **Post-generation integrity check in CI** — assert every referenced `png_file` / `thumbnail` exists in the deploy tree; fail the build otherwise.
16. **Generate first, swap second** in `ConvertTo-ZolaContent.ps1` — build into a temp directory, then replace.
17. **`--dry-run` flag** on the pipeline. For a batch job that mutates a network share and pushes to a remote, seeing the plan before executing is the cheapest safety feature available.
18. **Retry-with-backoff wrapper** for network calls, applied at roughly six sites.

## See Also

- `CLAUDE.md` — project documentation
- `docs/Test-EnvironmentConfiguration.md` — validation script reference
- `TagProcessingLogic.md` — tag extraction specification
