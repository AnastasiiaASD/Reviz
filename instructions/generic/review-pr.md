# Instruction: Review PR with Tests

## Objective
Review the pull request created in the previous step. Check test quality, 
correctness, and adherence to project standards before marking the task complete.
Read @/instructions/generic/project-description.md before starting.
Knowledge base with full feature documentation is at /app/knowledge-base/ — 
Read the relevant feature file before reviewing.

## ⛔ Token budget
- Do not re-run tests unless a specific failure needs investigation.
- Do not open a browser unless a selector needs verification.
- Max 1 snapshot if browser is needed.

## Workflow

### 1. Read the branch
```bash
cd /app/repo
git checkout tests/{{task-key}}
```

### 2. Review checklist
For each test file on the branch, verify:

- [ ] No hardcoded credentials — all secrets from `process.env.*.`
- [ ] No weak assertions (`toBeTruthy`) — only exact value checks
- [ ] Uses `authenticatedPage` fixture — no manual login code
- [ ] Uses existing Page Objects from `tests/pages/` — no duplicate selectors
- [ ] Test data uses `TestDataBuilder` — no random hardcoded strings
- [ ] Naming convention: `[TASK-ID]-[logic]-scenario-[N].spec.ts`
- [ ] Each test has `test.step()` blocks: Setup / Action / Assert
- [ ] No `.only` or `.skip` left in code
- [ ] No `console.log` left in code

### 3. If issues found
Fix them directly on the branch:
```bash
cd /app/repo
# make fixes
git add.
git commit -m "fix: review fixes for {{task-key}}"
```

### 4. Post review summary to Jira
Save summary to `/app/tmp/{{task-key}}_review.md` and post:
```bash
jira-ai add-comment \
  --file-path /app/tmp/{{task-key}}_review.md \
  --issue-key {{task-key}}
```
Delete the file after posting.

### 5. Move the task to "In Testing" status
```bash
jira-ai transition-issue {{task-key}} "In Testing"
```

### 6. Wait for QA confirmation before closing
Do NOT add any further labels or close the task.
**Wait for Anastasiia Shoshu to confirm the tests are accepted.**
