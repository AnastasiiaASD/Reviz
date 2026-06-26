# Ainela vs Reviz — Comparative Analysis

**Date:** 2026-06-20
**Author:** Reviz AI Agent (for review by Anastasiia Shoshu)
**Purpose:** Analyze Dana's `ainela` (le-ainella) reference implementation, compare against Reviz's current architecture, and recommend what to port.

---

## 1. Side-by-Side Architecture Comparison

### 1.1 Pipeline Phases & Label Flow

| Aspect | Ainela (le-ainella) | Reviz |
|--------|-------------------|-------|
| **Entry status** | `status = 'Prep Autotests'` | Phase 1: `status = 'Ready For Test'` with `reviz-qa` label; Phases 2-3: `status = 'In Testing'` |
| **Label: Phase 1 gate** | `labels IS EMPTY OR (labels != analyzed AND labels != qaed)` | `labels = 'reviz-qa'` (no analyzed/qaed yet) |
| **Label: Phase 2 gate** | `labels = analyzed AND labels != qaed` | `labels = 'reviz-qa' AND labels = analyzed AND labels != qaed` |
| **Label: Phase 3 gate** | `labels = analyzed AND labels = qaed AND labels != pr_created` | `labels = 'reviz-qa' AND labels = qaed AND labels != pr_created` |
| **Phase 4 (retest)** | Not implemented | Planned (`status = 'Ready for Retest'`, label `retested`) — not yet in code |
| **Scope label** | None (relies on `assignee = currentUser()` only) | `reviz-qa` — explicit scope label to isolate Reviz tickets |
| **Status transitions** | None — stays in `Prep Autotests` throughout | Phase 1 transitions ticket to `In Testing`; Phase 4 (review) transitions to `In Testing` |

### 1.2 JQL Queries

| Phase | Ainela JQL | Reviz JQL |
|-------|-----------|-----------|
| Phase 1 (analyze) | `assignee = currentUser() AND status = 'Prep Autotests' AND (labels IS EMPTY OR (labels != analyzed AND labels != qaed))` | `assignee = currentUser() AND status = 'Ready For Test' AND labels = 'reviz-qa'` |
| Phase 2 (scenarios) | `assignee = currentUser() AND status = 'Prep Autotests' AND (labels IS EMPTY OR (labels = analyzed AND labels != qaed))` | `assignee = currentUser() AND status = 'In Testing' AND labels = 'reviz-qa' AND labels = analyzed AND labels != qaed` |
| Phase 3 (write tests) | `assignee = currentUser() AND status = 'Prep Autotests' AND (labels IS EMPTY OR (labels = analyzed AND labels = qaed AND labels != pr_created))` | `assignee = currentUser() AND status = 'In Testing' AND labels = 'reviz-qa' AND labels = qaed AND labels != pr_created` |

**Key difference:** Ainela's Phase 1 JQL has a logical flaw — `labels IS EMPTY OR (labels != analyzed AND labels != qaed)` would also match tickets that have *only* `pr_created`, potentially re-analyzing completed tickets. Reviz avoids this by using the explicit `reviz-qa` scope label and separate status values.

### 1.3 Instruction Files

| File | Ainela Path | Reviz Path | Notes |
|------|------------|-----------|-------|
| Analyze task | `instructions/analyze-task.md` | `instructions/generic/analyze-task.md` | Different directory structure |
| Test scenarios | `instructions/test-scenarios.md` | `instructions/generic/test-scenarios.md` | Reviz adds Confluence publishing |
| Write tests | `instructions/write-tests.md` | `instructions/generic/write-tests.md` | Domain-specific adaptations |
| Review PR | `instructions/review-pr.md` | `instructions/generic/review-pr.md` | **Critical difference: auto-merge vs manual checkpoint** |
| Project description | `instructions/generic/project-description.md` | `instructions/generic/project-description.md` | Same path, different product context |
| Playwright CLI guide | `instructions/generic/how-to-use-playwright-cli.md` | `instructions/generic/how-to-use-playwright-cli.md` | Identical structure |
| Maintenance | `instructions/maintnance.md` | Not present | Ainela-only |
| Knowledge base | Not present | `/app/knowledge-base/` (cloned at startup) | Reviz-only |
| Confluence API | Not present | `confluence-api.js` | Reviz-only |

### 1.4 Orchestration (look-for-tasks.sh)

| Feature | Ainela | Reviz |
|---------|--------|-------|
| Tests repo | `danakoshelnik-787/le-tests` | `[GITHUB_ORG_OR_USER]/revyoos-qa-automation` |
| Branch naming | `tests/${TASK_ID}` | `tests/${TASK_ID}` |
| Task detail pre-fetch | Yes — `prefetch_task_details()` | Yes — identical implementation |
| Branch cleanup | Deletes branches identical to `main` before clone | Same approach |
| Instruction symlink | `ln -sfn /app/instructions /app/repo/instructions` | Same approach |
| PR creation | Direct GitHub REST API via `curl` | Same approach |
| Review step | Runs `review-pr.md` via opencode after PR | Same approach |
| Final push after review | Yes — pushes review commits | Same approach |

### 1.5 Infrastructure

| Component | Ainela | Reviz |
|-----------|--------|-------|
| Base image | `node:20-slim` | `node:20-slim` |
| LLM engine | OpenCode Go (opencode-go/) | OpenCode Go (opencode-go/) |
| Default models | analyze: `deepseek-v4-flash`, write: `qwen3.6-plus`, review: `deepseek-v4-flash` | Identical defaults |
| Run modes | webhook / cron / loop | webhook / cron / loop |
| Webhook secret header | `X-Ainella-Secret` | `X-Reviz-Secret` |
| Concurrency lock | `flock /tmp/ainella-task.lock` | `flock /tmp/reviz-task.lock` |
| Knowledge base clone | No | Yes — clones `revyoos-knowledge-base` at startup |
| Confluence integration | No | Yes — `confluence-api.js` + `CONFLUENCE_SPACE_KEY` |
| `.env.example` | No | Yes |
| `README.md` | No | Yes |
| Jira auth error handling | Hard fail on missing `JIRA_JSON` | Soft fail with `|| echo WARN` (more resilient) |

---

## 2. Components in Ainela That Are Better or More Robust

### 2.1 Maintenance Mode (`instructions/maintnance.md`) — BETTER

**What it does:** A dedicated workflow for periodic health checks of the entire test suite:
1. Runs full test suite, waits for completion
2. Skips any failing tests
3. Analyzes each skipped test for root cause (website changed, flaky, poorly written, concurrency issue)
4. Fixes tests per root cause category
5. Commits, pushes, and generates a maintenance report to `app/logs/{date}-maintn-report.md`

**Why it's better:** Reviz has no equivalent. Test suite health degrades over time as the Revyoos UI changes, and without a periodic maintenance sweep, failing/flaky tests accumulate. This is particularly important for a review platform with OTA integrations that evolve independently.

**Recommendation:** **Port with modification.** Adapt to Reviz conventions:
- Save report to Jira comment + Confluence page instead of local file
- Use Reviz's knowledge base for context during RCA
- Add as a separate `RUN_MODE=maintenance` or a separate webhook endpoint

### 2.2 Entrypoint Fallback Polling Loop — NEUTRAL (already present)

Ainela's `entrypoint.sh` has a dead-code fallback loop at lines 175-183 that runs after the `case` block. This is unreachable in practice (the `webhook` case uses `exec`) and appears to be leftover from an earlier version. Reviz correctly does not have this dead code.

**Recommendation:** **Do not port.** Reviz's entrypoint is cleaner.

### 2.3 Per-Step Model Split Comments — IDENTICAL

Both repos document the model split rationale in `entrypoint.sh`. No advantage either way.

**Recommendation:** **No action needed.**

### 2.4 Write-Tests Instruction: Domain-Specific Guard Rails — AINELA STRONGER

Ainela's `write-tests.md` includes detailed, product-specific guidance that Reviz could benefit from structurally:

| Ainela Feature | Reviz Equivalent | Gap |
|----------------|-----------------|-----|
| Persistent test websites (`autotestupdate.saloniki.tours`, `autotestdelete.saloniki.tours`) with DNS delay handling | "Persistent Test Properties" section — less detailed | Minor gap — Reviz covers this conceptually |
| Mandatory `process.env.TEST_EMAIL` guard for persistent-website specs | Generic "no hardcoded secrets" rule | Reviz could add a similar guard for its test account |
| Supplier API test credentials section (FareHarbor, Ventrata) | Not applicable | N/A — different product |
| `hexToRgb()` assertion pattern for CSS color checks | Generic "exact value assertions" rule | Minor gap |
| `EnvironmentConfig.PERSISTENT_DOMAINS` pattern | `propertyHelper.ensurePropertyExists()` | Architecturally equivalent |

**Recommendation:** **Port the pattern, not the content.** Add Revyoos-specific guard rails:
- Mandatory test account guard (e.g., `process.env.TEST_EMAIL` for demo env tests)
- Explicit Stripe test-mode credential handling rules
- OTA mock/sandbox credential patterns

### 2.5 Review-PR: Auto-Merge with Zero-Tolerance Delete Policy — AINELA MORE AGGRESSIVE

Ainela's `review-pr.md` has a clear, opinionated policy:
- If any test **fails or is flaky → delete it immediately**
- After review, **merge directly to main and delete the branch**
- Labels the task as `covered` (not `pr_created`)

**This is an area of significant difference — see Section 3 below.**

### 2.6 Test Scenario File Structure — COMPARABLE

Both repos use a similar markdown table format for scenarios (Number | Scenario | Details | Result). Ainela calls it "Expeced File Structure" (typo preserved). Reviz adds the Confluence publishing step, which is an improvement over Ainela's Jira-only approach.

**Recommendation:** **No action needed.** Reviz is already better here with Confluence integration.

---

## 3. Components INCOMPATIBLE with Reviz's Checkpoint Model

### 3.1 AUTO-MERGE IN REVIEW STEP (CRITICAL CONFLICT)

**Ainela behavior (`review-pr.md`, steps 3-5):**
```bash
# Ainela merges directly:
git checkout main
git pull origin main
git merge {{branch-name}}
git push origin main
git branch -d {{branch-name}}
git push origin --delete {{branch-name}}
```

**Reviz behavior (`review-pr.md`, step 6):**
```
Do NOT add any further labels or close the task.
Wait for Anastasiia Shoshu to confirm the tests are accepted.
```

**Conflict:** Ainela's auto-merge bypasses human review entirely. Reviz explicitly requires QA approval before any merge occurs.

**Recommendation:** **DO NOT PORT.** This is the known decision point flagged in the task brief. Auto-merge must not be implemented without Nastya's explicit written approval. The current checkpoint (QA reviews PR → QA merges) is a deliberate safety net for a production review management platform where test quality directly impacts data integrity.

### 3.2 AUTOMATIC BRANCH DELETION

**Ainela:** Deletes the feature branch after merge (`git push origin --delete {{branch-name}}`)

**Reviz:** Does not delete branches — leaves them for QA review.

**Conflict:** Branch deletion before QA review removes the ability to inspect the agent's work.

**Recommendation:** **Do not port.** Branch deletion should only happen after QA confirms and merges the PR.

### 3.3 ZERO-TOLERANCE TEST DELETION POLICY

**Ainela (`review-pr.md`):**
> If any of the tests are **failing** or **flaky**, **delete them immediately**. We only merge stable, passing tests.

**Reviz:** No equivalent policy — relies on QA judgment during PR review.

**Assessment:** This is partially compatible. The "delete failing tests" approach keeps `main` green but loses information about what the agent attempted. For a human-reviewed workflow, it's better to keep failing tests in the PR (marked as `test.skip` with a comment) so QA can evaluate whether the test logic is correct but the app has a bug.

**Recommendation:** **Port with modification.** Instead of deleting failing tests:
1. Mark them as `test.skip('blocker: [reason]')` in the PR
2. Include the failure reason in the Jira report
3. Let QA decide whether to keep, fix, or remove them during PR review

### 3.4 LABEL: `covered` vs `pr_created`

**Ainela:** Uses `covered` as the final label after merge + review.
**Reviz:** Uses `pr_created` after test writing, with future `retested` label planned for Phase 4.

**Assessment:** Not a conflict per se, but `covered` implies a completed workflow, while `pr_created` correctly reflects that the PR exists but hasn't been reviewed. Reviz's naming is more accurate for its checkpoint model.

**Recommendation:** **Do not port.** Reviz's label naming is correct for its workflow.

### 3.5 TASK ASSIGNMENT TARGET

**Ainela:** Assigns to `"712020:7b5046c5-bbbe-45dc-a99c-9459242930c7"` (Anastasiia Brynzan)
**Reviz:** Assigns to `"712020:f5e4ea9b-86f3-42d8-9a02-b35dfd8f01bc"` (Anastasiia Shoshu)

**Assessment:** Different people on different projects — no conflict, just a mapping difference.

**Recommendation:** **No action needed.** Already correctly configured per project.

---

## 4. Detailed Recommendation Summary

| # | Component | Source | Recommendation | Priority | Effort |
|---|-----------|--------|---------------|----------|--------|
| 1 | Maintenance mode | `ainela/instructions/maintnance.md` | **Port with modification** — adapt for Reviz conventions (Confluence report, knowledge base context) | Medium | Medium |
| 2 | Auto-merge in review step | `ainela/instructions/review-pr.md` | **DO NOT PORT** — conflicts with Reviz's QA checkpoint model. Requires explicit Nastya approval to change. | N/A | N/A |
| 3 | Automatic branch deletion | `ainela/instructions/review-pr.md` | **Do not port** — removes QA's ability to inspect agent work | N/A | N/A |
| 4 | Zero-tolerance test deletion | `ainela/instructions/review-pr.md` | **Port with modification** — change to `test.skip` + report instead of delete | Low | Low |
| 5 | Test account guard pattern | `ainela/instructions/write-tests.md` | **Port the pattern** — add Revyoos-specific credential guards | Low | Low |
| 6 | Persistent test data documentation | `ainela/instructions/write-tests.md` | **Already equivalent** in Reviz | N/A | N/A |
| 7 | `covered` label | `ainela/instructions/review-pr.md` | **Do not port** — Reviz's `pr_created` naming is more accurate | N/A | N/A |
| 8 | Phase 1 JQL fix | `ainela/look-for-tasks.sh` | **Do not port** — Reviz's JQL is already more precise (uses `reviz-qa` scope label) | N/A | N/A |

---

## 5. Decision Point: Auto-Merge

This is the one item that requires a clear decision from Nastya before proceeding:

**Current state:** After Phase 3 (write-tests), Reviz creates a PR on GitHub and posts a Jira comment. The agent then runs a code review pass (`review-pr.md`) that checks test quality, fixes minor issues, and posts a review summary. After that, the agent **stops and waits for QA confirmation**.

**Ainela's approach:** The review step auto-merges passing tests to `main` and deletes the branch. Failing/flaky tests are deleted before merge.

**Options:**

| Option | Description | Risk |
|--------|-------------|------|
| A. Keep current (recommended) | PR stays open for QA review. QA merges manually. | Low — but slower turnaround |
| B. Auto-merge with notification | If all tests pass, merge automatically but notify QA via Jira comment. QA can revert. | Medium — bad test merged before QA can catch it |
| C. Auto-merge for passing, skip for failing | Ainela's approach. Only merge green PRs. | Medium-High — removes QA checkpoint entirely |
| D. Conditional auto-merge | Auto-merge only if QA has pre-approved scenarios in Phase 2 AND all tests pass | Low-Medium — preserves Phase 2 checkpoint |

**My recommendation: Option A (keep current).** The QA review step catches issues that automated test passes cannot — wrong assertions, missing edge cases, tests that pass but don't actually verify the intended behavior. This is especially important for Revyoos where review data integrity matters.

---

## 6. What Reviz Already Does Better Than Ainela

For completeness, these are Reviz improvements that should NOT be reverted:

1. **Confluence integration** — Ainela posts everything to Jira comments only. Reviz publishes structured test scenarios to Confluence, making them searchable and organized.
2. **Knowledge base** — Reviz clones `revyoos-knowledge-base` at startup and references it in all instruction files. Ainela has no equivalent documentation source.
3. **Scope label (`reviz-qa`)** — Prevents the agent from accidentally picking up non-QA tickets.
4. **Status transitions** — Reviz transitions tickets between Jira statuses (`Ready For Test` → `In Testing`). Ainela leaves everything in `Prep Autotests`.
5. **Explicit QA checkpoints** — After every phase, Reviz stops and waits for human confirmation. This is a feature, not a limitation.
6. **`.env.example`** — Documents required env vars. Ainela has no onboarding guide for env setup.
7. **`README.md`** — Full setup and deployment documentation.
8. **Jira auth resilience** — Reviz's entrypoint uses `|| echo "WARN"` for soft failure instead of hard-crashing.

---

## 7. Decision Record (2026-06-20)

**Status: IMPLEMENTED** — Per Dana's direction (planning meeting 2026-06-19)
and Nastya's confirmation, the following decisions were made:

| # | Item | Decision | Commit |
|---|------|----------|--------|
| 1 | Auto-merge on passing tests | **ADOPTED** — PR auto-merged, branch deleted | `feat: auto-merge on pass, label-strip retry on fail` |
| 2 | Label-strip retry on failure | **ADOPTED** — all labels stripped, ticket re-enters from Phase 1 | (same commit) |
| 3 | Manual PR-review checkpoint | **REMOVED** — only 2 human checkpoints remain (Phase 1, Phase 2) | (same commit) |
| 4 | Maintenance mode | **PORTED** with Reviz adaptations (Confluence, knowledge base) | `feat: maintenance mode, test-skip-on-failure, test account guard` |
| 5 | Test-skip-on-failure | **PORTED** — `test.skip` replaces deletion | (same commit) |
| 6 | Test account guard | **PORTED** — pre-flight precondition checks | (same commit) |

**Open question (for Nastya):** Label naming — currently keeping Reviz's
existing `pr_created` label (just changing the behavior to auto-merge).
Should we rename to `covered` to match ainela for cross-repo consistency?
Default: keep `pr_created`.

**Files not found in repo:**
- `reviz-project-plan.md` — does not exist; changelog added to `README.md` instead
- `RevizDocumentationEN.pdf` — no source found in repo; needs manual update by Nastya
