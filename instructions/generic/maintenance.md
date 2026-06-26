# Instruction: Run Maintenance

Periodic health check of the test suite. Identifies broken/flaky tests,
diagnoses root causes, and fixes or skips them. Reports findings to Jira
and Confluence.

Read @/instructions/generic/project-description.md before start.
Knowledge base with full feature documentation is at /app/knowledge-base/ —
read the relevant feature files when diagnosing test failures.

## ⛔ Token budget

Maintenance can touch many test files. Stay efficient:

- **Do not open a browser unless a test failure clearly stems from a changed UI
  element.** Most failures can be diagnosed from the error message and existing
  Page Objects.
- If you do open a browser, respect the snapshot budget in
  @/instructions/generic/how-to-use-playwright-cli.md (max 2 snapshots, always
  `--filename`, never bare).

## Workflow

### 1. Execute full test suite
```bash
cd /app/repo
nohup npx playwright test --reporter=list > /tmp/test-run.log 2>&1 &
echo "Test started with PID: $!"
echo "Log file: /tmp/test-run.log"
```

Wait for completion (check every 5 minutes, up to 60 minutes total):
```bash
# Check if still running
ps aux | grep playwright | grep -v grep
# When done, review results
cat /tmp/test-run.log
```

### 2. Analyze results

For each failing test, determine root cause:

| Root Cause | Action |
|-----------|--------|
| **(a) UI changed** — selector/page structure no longer matches | Update test + Page Object to match new UI. Use @/instructions/generic/how-to-use-playwright-cli.md to inspect. |
| **(b) Flaky** — timing issue, race condition, inconsistent pass/fail | Strengthen assertions, add explicit waits, or increase timeout for known slow operations. |
| **(c) Poorly written** — test logic is fundamentally wrong | Rewrite following @/instructions/generic/write-tests.md rules. |
| **(d) Ordering dependency** — fails only when run with other tests | Isolate shared state, add proper setup/teardown, ensure test independence. |
| **(e) Environment issue** — credentials expired, service down, data missing | Mark with `test.skip('blocker: [environment issue description]')`. Do not attempt to fix environment problems. |

### 3. Fix tests per root cause

For each failing test:
1. Apply the fix matching its root cause category above
2. Re-run the individual test to verify the fix:
   ```bash
   npx playwright test tests/[test-file].spec.ts
   ```
3. If the fix doesn't resolve it after one attempt, mark with `test.skip`:
   ```typescript
   test.skip('TC-001: Description — maintenance-skip: [reason], [date]',
     async ({ page }) => { ... });
   ```
4. Commit each fix individually:
   ```bash
   git add .
   git commit -m "fix(maintenance): [test-file] — [brief description of fix]"
   ```

### 4. Push fixes to remote
```bash
git push origin main
```

### 5. Generate maintenance report

Create report at `/app/tmp/maintenance-report.md`:

```markdown
# Maintenance Report — [date]

## Summary
- Total tests: [N]
- Passing: [N]
- Fixed: [N]
- Skipped (environment): [N]
- Still failing: [N]

## Fixes Applied
| Test File | Root Cause | Fix Description |
|-----------|-----------|-----------------|
| [file] | [a/b/c/d/e] | [what was changed] |

## Tests Marked as Skipped
| Test File | Reason |
|-----------|--------|
| [file] | [why it can't be fixed in maintenance] |

## Recommendations
- [any patterns noticed, e.g. "3 tests broke due to new sidebar layout"]

— 🤖 Reviz AI Agent (maintenance run)
```

### 6. Publish to Confluence (if configured)

If `CONFLUENCE_SPACE_KEY` is set, publish the report:
```bash
node /app/confluence-api.js upsert "$CONFLUENCE_SPACE_KEY" "Maintenance Report [date]" /app/tmp/maintenance-report.md "$CONFLUENCE_PARENT_PAGE_ID"
```

### 7. Post summary to Jira (optional)

If a maintenance Jira ticket exists, post the summary:
```bash
jira-ai add-comment --file-path /app/tmp/maintenance-report.md --issue-key {{task-key}}
```

### 8. Cleanup
```bash
rm -f /app/tmp/maintenance-report.md
rm -f /tmp/test-run.log
```
