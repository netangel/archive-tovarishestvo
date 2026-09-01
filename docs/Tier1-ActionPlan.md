# Tier 1 Action Plan

**Date:** 2026-09-01
**Source:** [ArchitectureReview.md](ArchitectureReview.md) — Tier 1 recommendations
**Estimated effort:** ~1 day including tests
**Goal:** Restore the main entry point and make failures reportable. No change to the happy path, with one intentional exception (Step 2).

## Two constraints found while planning

These invalidate the obvious implementations. Read before starting.

**A. The naive JSON fix does not work.** `Test-EnvironmentConfiguration.ps1` calls `$provider.TestOpenMergeRequests()` at line 246, which emits `Write-Host` output. `Write-Host` is captured by `& pwsh -File ...`, so joining all captured lines produces:

```
FAILS: Unexpected character encountered while parsing value: П. Path '', line 0, position 0.
```

The JSON must be isolated from the surrounding chatter, not merely reassembled.

**B. `TestOpenMergeRequests` must not be changed to rethrow.** Two existing tests pin its swallow-and-return-`$false` contract:

- `tests/OpenMRCheck.Tests.ps1:149` — `{ Test-OpenMergeRequests ... } | Should -Not -Throw`
- `tests/OpenMRCheck.Tests.ps1:160-165` — returns `$false` on 404

Add a new method instead of modifying this one.

Verified as safe: no test references `Push-GitCommit`, `Invoke-GitOperation`, `Test-GitConnection`, or `Add-AllNewFiles` — Steps 1, 2 and 6 have no test contract to break (and no safety net either, hence the new tests below). All path fixtures in `tests/Test-EnvironmentConfiguration.Tests.ps1` already use `MetadataPath = Join-Path $resultPath "metadata"` (lines 41, 301, 377), so Step 5 breaks nothing.

## Step 1 — Replace `exit 1` in library code with `throw`

Foundational; Step 2 depends on it.

**Files:** `libs/GitHelper.psm1`, `Submit-MetadataToRemote.ps1`

1. `libs/GitHelper.psm1:81-84` — replace `exit 1` with a `throw` carrying the operation name, exit code and stderr:
   ```powershell
   throw "git $OperationName failed (exit $($result.ExitCode)): $($result.StdErr)"
   ```
2. `Submit-MetadataToRemote.ps1:32-34` — replace the empty catch (the `<#Do this if a terminating exception happens#>` placeholder) with `Exit-WithError "..."`.

**Gotcha:** `Submit-MetadataToRemote.ps1` imports only `GitHelper` (line 13). `Exit-WithError` lives in `ToolsHelper`, so add `Import-Module (Join-Path $PSScriptRoot "libs/ToolsHelper.psm1") -Force`. `Sync-MetadataGitRepo.ps1` already imports both (lines 16-17) and needs no change — its existing catch starts working as written.

**Verify:** point `Sync-MetadataGitRepo.ps1` at a directory whose `origin` does not match `-UpstreamUrl`. Before: bare process death. After: the Russian-language error message from the catch block, exit 1.

**Test to add:** `tests/GitHelper.Tests.ps1` — mock a failing `Invoke-GitCommand`, assert the exported function throws rather than terminating the runspace.

## Step 2 — Treat "nothing to commit" as success

**This one intentionally changes behavior**, per the review: a run where nothing changed currently reports *"❌ Не получилось создать и отправить список изменений"*. `git commit` exits 1 on a clean tree (verified).

**Files:** `libs/GitHelper.psm1`, `Submit-MetadataToRemote.ps1`, `Complete-ArchiveProcess.ps1`

1. In `Push-GitCommit` (`GitHelper.psm1:174`), before committing, run `git status --porcelain`. If output is empty: log "нет изменений для отправки", skip both the commit and the push, and return a sentinel the caller can read.
2. `Submit-MetadataToRemote.ps1` exits `2` for "no changes", `0` for "pushed", `1` for failure.
3. `Complete-ArchiveProcess.ps1:111-115` — treat exit `2` as success, skip MR creation, and print a "нечего публиковать" message instead of the error.

**Why check after `Add-AllNewFiles`:** `git add *` is a glob pathspec and `git commit -a` only covers tracked files. `git status --porcelain` after the add sees everything, including deletions.

**Why skip the push too:** the branch was just cut from `main`, so pushing an unchanged branch would open an empty merge request.

**Verify:** run the pipeline twice with no new scans. The second run should exit 0 with "nothing to publish" and open no MR.

**Test to add:** in `tests/GitHelper.Tests.ps1`, a real `git init` fixture in `TestDrive`, committed once — assert `Push-GitCommit` returns the no-change sentinel and invokes no `push`.

## Step 3 — Fix the validation JSON handoff

The confirmed break in the main entry point (`Complete-ArchiveProcess.ps1:37`).

**Files:** `Test-EnvironmentConfiguration.ps1`, `Complete-ArchiveProcess.ps1`

Preferred — stop scraping stdout:

1. Add an optional `[string]$OutputFile = ""` parameter to `Test-EnvironmentConfiguration.ps1`. When set, write the JSON there (`Set-Content -Encoding UTF8`) in addition to stdout, so standalone CLI behavior is unchanged.
2. In `Complete-ArchiveProcess.ps1`, create a temp path with `New-TemporaryFile`, pass it via `-OutputFile`, read and parse the file after the exit-code check, and remove it in a `finally`.

Minimal alternative, if you would rather not touch the validation script's signature: emit with `-Compress` (line 277) so the JSON is one line, and in the orchestrator select the **last** line that parses as JSON rather than filtering on `^\s*[\{\[]`. This works — verified — but stays sensitive to anything else that prints a brace.

**Do not** simply `-join` the captured lines. See constraint A above.

**Verify:** run `./Complete-ArchiveProcess.ps1` against a valid config. It must get past "✅ Environment validation passed" and reach the git sync step. This is currently impossible.

**Test to add:** `tests/Complete-ArchiveProcess.Tests.ps1` — the highest-value gap in the suite. Stub the four subprocess calls and assert (a) validated paths reach the child scripts, (b) each non-zero exit code aborts, (c) exit `2` from Step 2 is handled as success.

## Step 4 — Make the API connectivity check able to fail

Currently `Test-EnvironmentConfiguration.ps1:245-249` wraps a call that swallows its own exceptions, so an expired token passes validation.

**Files:** `libs/GitServerProvider.psm1`, `Test-EnvironmentConfiguration.ps1`

1. Add `[void] TestConnection()` to the `GitServerProvider` base class (throwing "must be implemented"), and implement it in both `GitLabProvider` and `GiteaProvider` as a bare `Invoke-RestMethod` against the same endpoint **with no try/catch** — let it throw.
2. Change `Test-EnvironmentConfiguration.ps1:246` from `$null = $provider.TestOpenMergeRequests()` to `$provider.TestConnection()`. The surrounding try/catch at 245-249 then works as intended.

**Do not** change `TestOpenMergeRequests`. See constraint B above.

**While here:** `GitServerProvider.psm1:99` does `$_.Exception.Response | ConvertFrom-Json` on an `HttpResponseMessage`, which always fails. Copy the working pattern from the Gitea sibling at line 193 (`$_.ErrorDetails.Message`).

**Verify:** `GITEA_TOKEN=invalid ./Test-EnvironmentConfiguration.ps1` must exit 1 with "Failed to query Gitea API". Today it exits 0.

**Test to add:** extend `tests/OpenMRCheck.Tests.ps1` with a `TestConnection` context asserting it *does* throw on a mocked failure — the mirror of the existing no-throw assertions.

## Step 5 — Assert the two metadata paths agree

`Convert-ScannedFIles.ps1:31` writes to `$ResultPath/metadata`; `Complete-ArchiveProcess.ps1:43` commits `config.MetadataPath`. Divergence silently commits an empty directory, surfacing as the misleading failure Step 2 addresses.

**File:** `Test-EnvironmentConfiguration.ps1`

After the existing suffix check (lines 113-120), add: if both `ResultPath` and `MetadataPath` resolved, compare `Join-Path $ResultPath 'metadata'` against `MetadataPath`. Normalize both with `[IO.Path]::GetFullPath` before comparing — the config holds UNC paths with mixed separators. On mismatch, `Add-ValidationError` naming both values.

**Note:** `config.json` currently ships `"MetadataPath": ""`, so this check is inert until the field is populated locally — the existing "not defined" error fires first.

**Verify:** set `MetadataPath` to a directory outside `ResultPath`; validation must fail with both paths in the message.

**Test to add:** a case in `tests/Test-EnvironmentConfiguration.Tests.ps1` with deliberately divergent paths, asserting exit 1.

## Step 6 — Real Git URL normalization

`TrimEnd('.git')` is a character-set trim, not a suffix trim: `.../digit` becomes `.../d`. It is applied symmetrically so equality usually survives, but it does not normalize scp-style `git@host:org/repo.git` against `ssh://git@host:port/org/repo.git`, which will false-mismatch. The logic is also duplicated.

**Files:** `libs/GitHelper.psm1`, `Test-EnvironmentConfiguration.ps1`

1. Add and export `ConvertTo-NormalizedGitUrl` in `GitHelper.psm1`: strip a trailing `/`, strip a trailing `.git` by suffix (`-replace '\.git$', ''`), rewrite scp-style `user@host:path` to `ssh://user@host/path`, drop the port, and lowercase the host.
2. Replace both call sites: `GitHelper.psm1:119-120` and `Test-EnvironmentConfiguration.ps1:171-172`.

**Verify:** with `config.GitRepoUrl` as `ssh://git@git.dwal.in:22022/solombala-archive/metadata.git` and the clone's origin as `git@git.dwal.in:solombala-archive/metadata`, validation must pass. Today it fails.

**Test to add:** `tests/GitHelper.Tests.ps1` — a table of equivalent URL pairs asserting equal normalization, plus the `digit` regression case.

## Execution order and verification

Steps 1 → 2 are ordered (2 relies on 1's error plumbing). Steps 3, 4, 5, 6 are independent and can be done in any order or in parallel.

Suggested sequencing: **1, 2** (error plumbing), then **3** (unblocks the entry point and lets you test 1 and 2 end to end), then **4, 5, 6** (validation hardening).

Definition of done:

1. `Invoke-Pester ./tests/` — all green, including the five new test files/contexts.
2. `./Test-EnvironmentConfiguration.ps1` exits 0 on a good config and exits 1 with an invalid `GITEA_TOKEN`.
3. `./Complete-ArchiveProcess.ps1` reaches the git sync step on a valid config.
4. A second consecutive run with no new scans exits 0, reports "nothing to publish", and opens no MR.
5. `git diff --stat` touches only: `libs/GitHelper.psm1`, `libs/GitServerProvider.psm1`, `Test-EnvironmentConfiguration.ps1`, `Complete-ArchiveProcess.ps1`, `Submit-MetadataToRemote.ps1`, and `tests/`.

## See Also

- [ArchitectureReview.md](ArchitectureReview.md) — full review, Tier 2 and Tier 3 items
- [Test-EnvironmentConfiguration.md](Test-EnvironmentConfiguration.md) — validation script reference
- `CLAUDE.md` — project documentation
