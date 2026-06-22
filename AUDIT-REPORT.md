# Reviz Code Audit & Architecture Analysis

**Date:** 2026-06-22
**Scope:** Full codebase audit of `AnastasiiaASD/Reviz`
**Goal:** Diagnose ticket transition failures and map the complete architecture

---

## Section 1: Architecture Overview

### System Diagram

```
                        ┌──────────────────────────────┐
                        │       Railway (Docker)        │
                        │                               │
                        │   entrypoint.sh               │
                        │     ├─ Jira auth (JIRA_JSON)  │
                        │     ├─ Git identity setup      │
                        │     ├─ Clone knowledge-base    │
                        │     ├─ Opencode auth + config  │
                        │     └─ Start RUN_MODE          │
                        │         ├─ webhook (default)   │
                        │         ├─ cron                │
                        │         └─ loop                │
                        └──────────┬───────────────────┘
                                   │
                          POST /run (or cron/loop)
                                   │
                                   ▼
                        ┌──────────────────────────────┐
                        │    look-for-tasks.sh          │
                        │    (flock — single instance)  │
                        └──────────┬───────────────────┘
                                   │
             ┌─────────────────────┼──────────────────────────┐
             │                     │                          │
             ▼                     ▼                          ▼
    ┌────────────────┐  ┌──────────────────┐       ┌────────────────────┐
    │ Phase 1: JQL   │  │ Phase 2: JQL     │       │ Phase 3: JQL       │
    │ Ready For Test │  │ In Testing       │       │ In Testing         │
    │ + reviz-qa     │  │ + analyzed       │       │ + scenarios-done   │
    │ - analyzed     │  │ - scenarios-done │       │ - pr_created       │
    └───────┬────────┘  └───────┬──────────┘       └───────┬────────────┘
            │                   │                          │
            ▼                   ▼                          ▼
   transition_status()    opencode run             git clone test repo
   "In Testing"           test-scenarios.md        opencode run write-tests.md
            │                   │                  git push + create PR
            ▼                   │                  post Jira comment
   opencode run                 │                  add label pr_created
   analyze-task.md              │                          │
            │                   │                          │
            ▼                   ▼                          ▼
   add label: analyzed   add label:              ┌─────────────────────┐
   post Jira comment     scenarios-done          │ Phase 4: JQL        │
   ⚠️ ALSO tries to      post Jira comment       │ In Testing          │
   transition to                                  │ - retested          │
   "In Testing" again                             └───────┬─────────────┘
                                                          │
                                                          ▼
                                                 opencode run retest.md
                                                 (⚠️ FILE MISSING)
                                                          │
                                                          ▼
                                                 transition_status()
                                                 "Production"
```

### Run Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| `webhook` (default) | `POST /run` with optional `X-Reviz-Secret` header | Spawns `look-for-tasks.sh` in background thread |
| `cron` | Railway Cron schedule | Runs once, exits |
| `loop` | Continuous | Runs every `POLL_INTERVAL` seconds (default 3600) |

### Concurrency Protection

`flock -n /tmp/reviz-task.lock` ensures only one `look-for-tasks.sh` runs at a time. If a run is already in progress, new triggers are silently skipped (webhook returns 202 but the task is dropped).

### Early Exit Pattern

The orchestrator (`look-for-tasks.sh`) uses `exit 0` after processing any phase. This means **only one ticket in one phase is processed per invocation**. Priority order: Phase 1 > Phase 2 > Phase 3 > Phase 4.

---

## Section 2: Code Flow Analysis

### File Responsibilities

| File | Role |
|------|------|
| `entrypoint.sh` | Bootstrap: auth setup (Jira, Git, Opencode), knowledge-base clone, run mode selector |
| `look-for-tasks.sh` | Core orchestrator: JQL queries, phase routing, git operations, PR creation |
| `instructions/generic/analyze-task.md` | Phase 1 AI prompt: read ticket, post questions, add `analyzed` label |
| `instructions/generic/test-scenarios.md` | Phase 2 AI prompt: define scenarios, validate in browser, add `scenarios-done` label |
| `instructions/generic/write-tests.md` | Phase 3 AI prompt: write Playwright tests, commit to branch (no push) |
| `instructions/generic/review-pr.md` | PR review prompt (not wired into any phase in orchestrator) |
| `instructions/generic/project-description.md` | Context document about Revyoos product |
| `instructions/generic/how-to-use-playwright-cli.md` | Browser automation rules and token budget |
| `confluence-api.js` | Confluence page CRUD (not currently called from any phase) |
| `.github/workflows/reviz-pr-tests.yml` | CI: runs Playwright tests on PRs touching `tests/REV-*` |
| `Dockerfile` | Build: Node 20, jira-ai@0.6.12, opencode-ai, playwright, chromium |
| `docker-compose.yml` | Local dev config |

### Phase-by-Phase Flow

#### Phase 1: Analyze (`look-for-tasks.sh:53-68` + `analyze-task.md`)

1. **JQL:** `assignee = currentUser() AND status = 'Ready For Test' AND labels = reviz-qa AND labels NOT IN (analyzed)`
2. **Orchestrator transitions** ticket to "In Testing" via `transition_status()` (line 61)
3. Prefetches ticket details to `/app/tmp/{TASK_ID}_details.txt`
4. Calls `opencode run` with `analyze-task.md` prompt
5. **AI agent** reads cached details, optionally opens browser, generates questions
6. **AI agent** posts comment to Jira
7. **AI agent** adds `analyzed` label
8. **AI agent** attempts to transition to "In Testing" (step 4.5 in analyze-task.md)
9. **AI agent** assigns ticket to QA (Anastasiia Shoshu)
10. `exit 0`

#### Phase 2: Test Scenarios (`look-for-tasks.sh:70-82` + `test-scenarios.md`)

1. **JQL:** `assignee = currentUser() AND status = 'In Testing' AND labels = analyzed AND labels NOT IN (scenarios-done)`
2. Prefetches ticket details
3. Calls `opencode run` with `test-scenarios.md` prompt
4. **AI agent** defines scenarios, validates in browser
5. **AI agent** posts scenarios table to Jira
6. **AI agent** adds `scenarios-done` label
7. **AI agent** assigns back to QA
8. `exit 0`

#### Phase 3: Write Tests (`look-for-tasks.sh:84-222` + `write-tests.md`)

1. **JQL:** `assignee = currentUser() AND status = 'In Testing' AND labels = scenarios-done AND labels NOT IN (pr_created)`
2. Prefetches ticket details
3. **Orchestrator** clones `revyoos-qa-automation` repo to `/app/repo`
4. Runs `npm install`, symlinks instructions
5. Calls `opencode run` with `write-tests.md` prompt
6. **AI agent** creates branch `tests/{TASK_ID}`, writes tests, commits
7. **Orchestrator** verifies branch exists, pushes to GitHub
8. **Orchestrator** creates PR via GitHub API (curl)
9. **Orchestrator** posts Jira comment with PR link
10. **Orchestrator** adds `pr_created` label
11. Cleans up `/app/repo`
12. `exit 0`

#### Phase 4: Retest (`look-for-tasks.sh:224-246`)

1. **JQL:** `assignee = currentUser() AND status = 'In Testing' AND labels NOT IN (retested)`
2. Prefetches ticket details
3. Calls `opencode run` with `retest.md` (**FILE DOES NOT EXIST**)
4. On success: transitions to "Production"
5. `exit 0`

### Label State Machine

```
[no labels]      → Phase 1 picks up → adds "analyzed"
[analyzed]       → Phase 2 picks up → adds "scenarios-done"
[scenarios-done] → Phase 3 picks up → adds "pr_created"
[pr_created]     → Phase 4 picks up → adds "retested" (intended)
```

### Where Secrets Are Used

| Secret | Where Read | How Used |
|--------|-----------|----------|
| `JIRA_JSON` | `entrypoint.sh:5-9` | Parsed as JSON, written to temp `.env`, fed to `jira-ai auth --from-file` |
| `GH_TOKEN` | `entrypoint.sh:25`, `look-for-tasks.sh:10`, `look-for-tasks.sh:171` | Git clone auth, GitHub API PR creation |
| `OPENCODE_API_KEY` | `entrypoint.sh:66-84` | Written to `auth.json` in multiple opencode config dirs |
| `CONFLUENCE_SPACE_KEY` | `entrypoint.sh:15` | Checked but never used in any phase |
| `TRIGGER_SECRET` | `entrypoint.sh:131,161` | Webhook endpoint auth |

### Hardcoded Values

| Location | Value | Risk |
|----------|-------|------|
| `look-for-tasks.sh:3-4` | `TESTS_REPO_OWNER=AnastasiiaASD`, `TESTS_REPO_NAME=revyoos-qa-automation` | Defaults, overridable via env |
| `analyze-task.md:45` | QA user account ID `712020:f5e4ea9b-86f3-42d8-9a02-b35dfd8f01bc` | Hardcoded Jira account ID |
| `test-scenarios.md:51` | Same QA user account ID | Same |
| `Dockerfile:19` | `jira-ai@0.6.12` | Pinned version |
| `confluence-api.js:9` | Expects `cfg.host` and `cfg.email` from JIRA_JSON | Uses different key names than what `entrypoint.sh` parses |

---

## Section 3: Identified Issues

### CRITICAL — Duplicate Transition Attempt (Root Cause of REV-2875 Failure)

**Location:** `look-for-tasks.sh:61` AND `analyze-task.md:37-39`

The orchestrator transitions the ticket to "In Testing" at line 61 **before** calling the AI agent:

```bash
# look-for-tasks.sh:61
transition_status "$TASK_ID" "In Testing" || exit 1
```

Then the AI agent (following `analyze-task.md` step 4.5) tries the **same transition again**:

```bash
# analyze-task.md step 4.5
jira-ai transition-issue {{task-key}} "In Testing"
```

The second transition fails because the ticket is already in "In Testing" — Jira doesn't allow transitioning to the current status. This triggers a confusing error even though the first transition succeeded.

**Impact:** The AI agent reports a failure for a transition that already happened. Depending on how `opencode` handles this, it may cause the entire Phase 1 to appear failed.

### CRITICAL — Missing `retest.md` File

**Location:** `look-for-tasks.sh:232` references `@/instructions/retest.md`

```bash
opencode run "Please run @/instructions/retest.md for $TASK_ID..."
```

But no file `instructions/generic/retest.md` or `instructions/retest.md` exists in the repository. Phase 4 will always fail with a file-not-found error from opencode.

### HIGH — Phase 4 JQL Is Too Broad

**Location:** `look-for-tasks.sh:226`

```
assignee = currentUser() AND status = 'In Testing' AND labels NOT IN (retested)
```

This query does **not** require `pr_created` label. It could match tickets that are still in Phase 2 or Phase 3 (they are also "In Testing" without `retested`). The only thing preventing premature Phase 4 pickup is the execution order — Phase 2 and 3 queries run first. But if a ticket has `pr_created` and enters Phase 4 before the `retested` label is added, it works by accident rather than by design.

**Fix:** Change to: `...AND labels = pr_created AND labels NOT IN (retested)`

### HIGH — `review-pr.md` Is Not Wired Into Any Phase

The `review-pr.md` instruction file exists and describes a review step that includes transitioning to "In Testing", but it is never called from the orchestrator. The README mentions a "review" model tier (`OPENCODE_MODEL_REVIEW`) but no phase uses it.

### MEDIUM — README Is Outdated / Inconsistent

| What README Says | What Code Actually Does |
|-----------------|------------------------|
| Status: `Prep Autotests` | JQL uses `Ready For Test` |
| Label: `qaed` | Code uses `scenarios-done` |
| Three phases | Four phases (analyze, scenarios, write-tests, retest) |
| No mention of Phase 4 retest | Phase 4 exists in orchestrator |
| No mention of transition logic | Orchestrator transitions before Phase 1 and after Phase 4 |

### MEDIUM — Confluence API Is Dead Code

`confluence-api.js` is copied into the Docker image but never called from any phase or script. `CONFLUENCE_SPACE_KEY` and `CONFLUENCE_PARENT_PAGE_ID` are checked in entrypoint but unused.

### MEDIUM — JIRA_JSON Key Name Mismatch

`entrypoint.sh:7` parses `JIRA_JSON` generically (all keys become env vars). The `.env.example` shows keys as `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`.

But `confluence-api.js:6-9` expects keys named `host`, `email`, `token` (different names). If the same `JIRA_JSON` is used for both, Confluence calls will fail.

### MEDIUM — No Retry Logic Anywhere

- `transition_status()` attempts once, then marks `reviz-blocked` on failure
- Git push attempts once, then marks `reviz-blocked` on failure
- PR creation via curl attempts once, no retry
- Network-dependent operations (JQL queries, opencode calls) have no retry

### LOW — Token Budget vs Browser Snapshots

`analyze-task.md` and `test-scenarios.md` both allow up to 2 browser snapshots per session. Since the AI agent may burn through the 5-hour rolling quota, a single ticket could consume a disproportionate amount of the budget if both phases use maximum snapshots.

### LOW — `reviz-blocked` Label Never Gets Cleared Automatically

When `reviz-blocked` is set, the ticket is stuck. There's no JQL query that looks for `reviz-blocked` tickets, no retry mechanism, and no automatic cleanup. Manual intervention is always required.

### LOW — Phase 2 Assigns to QA but Phase 2 JQL Requires `assignee = currentUser()`

After Phase 1 assigns the ticket to QA (Anastasiia Shoshu), Phase 2's JQL requires `assignee = currentUser()` (the Reviz bot). The ticket must be re-assigned back to Reviz for Phase 2 to pick it up. This is by design (QA confirmation gate), but it's not documented.

---

## Section 4: Why REV-2875 Transition Is Failing

Based on the code analysis, there are **three likely causes** for the "In Testing" transition failure:

### Cause 1: Duplicate Transition (Most Likely)

The orchestrator successfully transitions the ticket to "In Testing" at `look-for-tasks.sh:61`. Then the AI agent, following `analyze-task.md` step 4.5, tries to transition to "In Testing" **again**. Jira rejects this because:

- The ticket is already in "In Testing" status
- There is no self-transition configured in the Jira workflow (most workflows don't have "In Testing" → "In Testing")

The AI agent sees this as a failure and may abort or report an error, even though the ticket is already in the correct status.

### Cause 2: Transition Name Mismatch

The code uses the string `"In Testing"` but Jira transitions are workflow-specific. The actual transition name in the Jira workflow might be:
- "Move to In Testing"
- "Start Testing"
- "In testing" (lowercase)
- A transition ID rather than a name

`jira-ai transition-issue` may require the exact transition name, not the target status name. If the Jira workflow has the transition named differently than the target status, it would fail.

### Cause 3: Permission / Workflow Constraint

The Jira user authenticated via `JIRA_JSON` may:
- Not have permission to transition tickets in the project
- Not have the "In Testing" transition available from the "Ready For Test" status
- Be restricted by a workflow validator (e.g., required fields not populated)
- Be restricted by a workflow condition (e.g., only certain roles can transition)

### Diagnosis Steps

1. **Check if the ticket is already in "In Testing"** when the error occurs → confirms Cause 1
2. **Run `jira-ai transitions <TASK_KEY>`** to list available transitions from current status → confirms/eliminates Cause 2
3. **Check Jira audit log** for REV-2875 to see if the first transition succeeded → confirms Cause 1
4. **Test manually:** `jira-ai transition-issue REV-2875 "In Testing"` from the command line → isolates auth issues

---

## Section 5: Recommendations

### Must Fix (Blocking)

| # | Issue | Fix | File |
|---|-------|-----|------|
| 1 | **Duplicate transition** | Remove step 4.5 from `analyze-task.md` — the orchestrator already handles this | `instructions/generic/analyze-task.md:37-39` |
| 2 | **Missing `retest.md`** | Create `instructions/generic/retest.md` with retest logic, or disable Phase 4 | New file or `look-for-tasks.sh:232` |
| 3 | **Phase 4 JQL too broad** | Add `AND labels = pr_created` to the Phase 4 JQL query | `look-for-tasks.sh:226` |

### Should Fix (High Priority)

| # | Issue | Fix | File |
|---|-------|-----|------|
| 4 | **`review-pr.md` not wired** | Either add a Phase 3.5 review step or remove the file | `look-for-tasks.sh` |
| 5 | **README outdated** | Update status names (`Ready For Test`), label names (`scenarios-done`), and document all 4 phases | `README.md` |
| 6 | **Transition name verification** | Add a helper that lists available transitions before attempting, or add `--verbose` flag to diagnose failures | `look-for-tasks.sh:32` |
| 7 | **`review-pr.md` also has duplicate transition** | Step 5 in `review-pr.md` transitions to "In Testing" but the ticket should already be there | `instructions/generic/review-pr.md:55-57` |

### Nice to Have

| # | Issue | Fix |
|---|-------|-----|
| 8 | Add retry logic (1-2 retries with backoff) for network operations | `look-for-tasks.sh` transitions, push, PR creation |
| 9 | Remove dead `confluence-api.js` or wire it into a phase | Clean up |
| 10 | Fix JIRA_JSON key name mismatch for Confluence | `confluence-api.js` |
| 11 | Add `reviz-blocked` recovery JQL or cleanup cron | New feature |
| 12 | Document the QA confirmation gate between phases | `README.md` |

### Testing Checklist

- [ ] Manually run `jira-ai transition-issue <KEY> "In Testing"` from a "Ready For Test" ticket to verify the transition name
- [ ] Run `jira-ai transitions <KEY>` to list all available transitions from each status
- [ ] Verify the Jira user (from JIRA_JSON) has transition permissions
- [ ] Test Phase 1 after removing step 4.5 from `analyze-task.md`
- [ ] Create `retest.md` and test Phase 4 end-to-end
- [ ] Verify Phase 4 JQL doesn't accidentally pick up Phase 2/3 tickets

---

## Appendix: Complete Label State Machine

```
Ticket Created
    │
    ▼
[Ready For Test] + [reviz-qa]        ← Entry condition
    │
    │  Phase 1 picks up (JQL match)
    │  Orchestrator: transition → "In Testing"
    │  AI: analyze, comment, add "analyzed"
    │  AI: assign to QA
    │
    ▼
[In Testing] + [reviz-qa, analyzed]   ← QA confirmation gate
    │
    │  QA re-assigns to Reviz bot
    │  Phase 2 picks up (JQL match)
    │  AI: scenarios, comment, add "scenarios-done"
    │  AI: assign to QA
    │
    ▼
[In Testing] + [reviz-qa, analyzed, scenarios-done]  ← QA confirmation gate
    │
    │  QA re-assigns to Reviz bot
    │  Phase 3 picks up (JQL match)
    │  Orchestrator: clone, AI writes tests, push, PR, comment
    │  Orchestrator: add "pr_created"
    │
    ▼
[In Testing] + [reviz-qa, analyzed, scenarios-done, pr_created]
    │
    │  Phase 4 picks up (JQL match — NEEDS FIX)
    │  AI: retest (FILE MISSING)
    │  Orchestrator: transition → "Production"
    │
    ▼
[Production] + [reviz-qa, analyzed, scenarios-done, pr_created, retested]
```

---

*Report generated by code audit of `AnastasiiaASD/Reviz` repository.*
