# Instruction: Retest — Verify Tests on Main Branch

## Objective
Re-run Playwright tests on the main branch after the PR from Phase 3 has been merged.
Confirm tests are stable before the ticket moves to Production.
Read @/instructions/generic/project-description.md before start.

## Token budget

- **Do not call `jira-ai task-with-details`.** The orchestrator already cached it at `/app/tmp/{{task-key}}_details.txt`. Read that file.
- **Do not open a browser.** This phase only runs existing tests — no manual validation needed.
- **Do not modify any test files.** If tests fail, report the failure; do not fix.

## Workflow

### 1. Read context
```bash
cat /app/tmp/{{task-key}}_details.txt
```

Confirm the ticket has `pr_created` label and a PR was merged in Phase 3.
Check Jira comments for the PR link from Phase 3.

### 2. Clone test repo and install
```bash
rm -rf /tmp/revyoos-tests
git clone https://x-access-token:${GH_TOKEN}@github.com/${TESTS_REPO_OWNER}/${TESTS_REPO_NAME}.git /tmp/revyoos-tests
cd /tmp/revyoos-tests
npm install
npx playwright install --with-deps chromium
```

### 3. Verify test folder exists
```bash
ls tests/{{task-key}}/
```

If the folder does not exist on `main`, the PR may not have been merged yet.
Post a Jira comment explaining the situation and stop:

```bash
cat > /app/tmp/{{task-key}}_retest.md <<'COMMENT'
Reviz Phase 4: test folder `tests/{{task-key}}/` not found on main branch.
The Phase 3 PR may not have been merged yet. Please merge the PR and re-trigger Reviz.

— Reviz AI Agent
COMMENT
jira-ai add-comment --file-path /app/tmp/{{task-key}}_retest.md --issue-key {{task-key}}
rm -f /app/tmp/{{task-key}}_retest.md
```

### 4. Run tests
```bash
cd /tmp/revyoos-tests
npx playwright test tests/{{task-key}}/ --reporter=list 2>&1 | tee /app/tmp/{{task-key}}_test_output.txt
```

Do not retry failed tests. A single failure counts as a failure.

### 5. Post results to Jira

#### If all tests passed:

Save to `/app/tmp/{{task-key}}_retest.md`:

```markdown
Reviz Phase 4: Retest

All tests passed on main branch for `tests/{{task-key}}/`.
Ticket is ready for production.

— Reviz AI Agent
```

Then add the `retested` label:

```bash
jira-ai add-comment --file-path /app/tmp/{{task-key}}_retest.md --issue-key {{task-key}}
rm -f /app/tmp/{{task-key}}_retest.md
jira-ai add-label-to-issue {{task-key}} retested
```

#### If tests failed:

Save to `/app/tmp/{{task-key}}_retest.md`:

```markdown
Reviz Phase 4: Retest

Tests failed on main branch for `tests/{{task-key}}/`.

Failed tests:
[paste relevant failure lines from /app/tmp/{{task-key}}_test_output.txt]

Needs investigation before production.

— Reviz AI Agent
```

Then mark as blocked:

```bash
jira-ai add-comment --file-path /app/tmp/{{task-key}}_retest.md --issue-key {{task-key}}
rm -f /app/tmp/{{task-key}}_retest.md
jira-ai add-label-to-issue {{task-key}} reviz-blocked
```

Do NOT add `retested` label on failure.

### 6. Clean up
```bash
rm -rf /tmp/revyoos-tests
rm -f /app/tmp/{{task-key}}_test_output.txt
```

The orchestrator handles the transition to Production after this step exits successfully.
Do NOT call `jira-ai transition` — the orchestrator does it.
