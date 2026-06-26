# Instruction: Review, Verify, and Finalize Tests

## Objective
Review the test code from Phase 3, run all tests, and write the outcome to a
result file. The orchestration script reads this file and handles merge (on pass)
or label-stripping for retry (on fail). There is no manual checkpoint here —
this step runs autonomously.

Read @/instructions/generic/project-description.md before starting.
Knowledge base with full feature documentation is at /app/knowledge-base/ —
read the relevant feature file before reviewing.

## ⛔ Token budget
- Do not open a browser — review reads diffs and runs tests only.
- One test run per file. Do not iterate on failures.
- Read cached Jira details from `/app/tmp/{{task-key}}_details.txt`.

## Workflow

### 1. Checkout and review the branch
```bash
cd /app/repo
git fetch origin
git checkout tests/{{task-key}}
```

Review the diff:
```bash
git diff main...HEAD
```

### 2. Review checklist
For each test file on the branch, verify:

- [ ] No hardcoded credentials — all secrets from `process.env.*`
- [ ] No weak assertions (`toBeTruthy`) — only exact value checks
- [ ] Uses `authenticatedPage` fixture — no manual login code
- [ ] Uses existing Page Objects from `tests/pages/` — no duplicate selectors
- [ ] Test data uses `TestDataBuilder` — no random hardcoded strings
- [ ] Naming convention: `[TASK-ID]-[logic]-scenario-[N].spec.ts`
- [ ] Each test has `test.step()` blocks: Setup / Action / Assert
- [ ] No `.only` or `console.log` left in code

### 3. Fix minor issues
If checklist issues are found, fix them directly:
```bash
cd /app/repo
# make fixes
git add .
git commit -m "fix: review fixes for {{task-key}}"
```

### 4. Run all tests on the branch
```bash
cd /app/repo
npx playwright test tests/{{test-file-pattern}}.spec.ts
```

### 5. Handle results

#### If ALL tests pass

1. Write result file:
```bash
echo "PASS" > /app/tmp/{{task-key}}_review_result.txt
```

2. Create completion report at `/app/tmp/{{task-key}}_review.md`:
```markdown
✅ All tests passed for {{task-key}}.

Tests will be auto-merged by Reviz.
Branch: tests/{{task-key}}

Summary:
- [N] test files reviewed
- [N] tests passed
- Review fixes applied: [yes/no]

— 🤖 Reviz AI Agent
```

3. Post to Jira:
```bash
jira-ai add-comment --file-path /app/tmp/{{task-key}}_review.md --issue-key {{task-key}}
```

4. Cleanup:
```bash
rm -f /app/tmp/{{task-key}}_review.md
```

#### If ANY test fails

1. For each failing test, mark it with `test.skip` and include the failure reason.
   Do NOT delete the test file — preserve the implementation for debugging:
```typescript
// Before:
test('TC-001: Should do something', async ({ page }) => { ... });

// After:
test.skip('TC-001: Should do something — blocker: [failure reason]', async ({ page }) => { ... });
```

   Commit the skip changes:
```bash
git add .
git commit -m "skip: mark failing tests for {{task-key}} with reason"
```

2. Write result file:
```bash
echo "FAIL" > /app/tmp/{{task-key}}_review_result.txt
```

3. Create failure report at `/app/tmp/{{task-key}}_review.md`:
```markdown
❌ Tests failed for {{task-key}} — ticket will be reprocessed.

Failing tests:
- [test file]: [failure reason / error message]

The failing tests have been marked with `test.skip`.
Phase labels will be stripped — this ticket will re-enter
the processing queue on the next run.

— 🤖 Reviz AI Agent
```

4. Post to Jira:
```bash
jira-ai add-comment --file-path /app/tmp/{{task-key}}_review.md --issue-key {{task-key}}
```

5. Cleanup:
```bash
rm -f /app/tmp/{{task-key}}_review.md
```

---
## Important: No manual checkpoint
This step runs **autonomously**. Do NOT wait for QA confirmation, do NOT
pause for human review. The orchestration script handles PR merge (on pass)
or label-stripping for retry (on fail) based on the result file you write.

Only two human checkpoints exist in the Reviz workflow:
1. After Phase 1 (analysis) — QA answers clarifying questions
2. After Phase 2 (scenarios) — QA selects which scenarios to implement

Phase 3/4 (write + review) runs to completion without human intervention.
