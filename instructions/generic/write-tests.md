# Instructions: Prepare Code for Tests

Follow this process for each test scenario in your task to ensure consistency, reliability, and proper documentation.
Read @/instructions/generic/project-description.md before start.
Knowledge base with full feature documentation is at /app/knowledge-base/ — read the relevant feature file before analyzing the task.

## ⛔ Token budget — read first

You are running on a flat-rate opencode-go subscription with a **5-hour rolling quota window**. One unfinished ticket can consume the entire window. Stay strictly inside these limits or the workflow stops for hours:

- **At most 2 `playwright-cli snapshot` calls per session**, and never bare — always `playwright-cli snapshot --filename=/tmp/snap.yml` then `grep`/`head` the section you need. Full-page snapshots dumped to stdout cost 5–15k tokens each.
- **Read existing Page Objects before opening a browser.** Run `ls /app/repo/tests/pages/` and `ls /app/repo/tests/helpers/` and read every relevant file. If a selector you need is already defined in a Page Object, you MUST reuse it and not browse for it. Only inspect the live site for widgets/flows that have no existing coverage.
- **Do not retry failing tests more than once.** If the first test run fails with a setup-stage `TimeoutError`, write the test as-is, mark the scenario as `blocker: setup unreachable` in the report, and move on. Selector-chasing loops are the #1 quota drain.
- **No exploratory `eval`/`console`/`network` calls.** Use `playwright-cli eval` only when targeting a specific element by ref and you already know what you're extracting.

## Flow preparation

- **Read cached Jira details first.** The orchestrator pre-fetches them to `/app/tmp/{{task-key}}_details.txt` — read that file. Do not re-run `jira-ai task-with-details`.
- **Run through scenarios manually:** use @/instructions/generic/how-to-use-playwright-cli to inspect the real website *only for scenarios not covered by existing Page Objects* (see token budget rule above).

## 1. Scenario Implementation Workflow

For each scenario THAT IS APPROVED IN THE TICKET:

- **Create new branch:** `tests/[TASK-ID]`
- **Create Test Code:** Write the test implementation and save it in the `/app/repo/tests/` directory.
- **Naming Convention:** Use the format: `[TASK-ID]-[logic-description]-scenario-[number].spec.ts`
    - *Example*: `REV-123-property-creation-scenario-1.spec.ts`

## 2. Verification and Debugging

- **Execute the Test:** Run the test immediately after creation to verify it passes.
- **Handle Failures:**
    - If the test fails, attempt to debug and fix the test code.
- **Identify Implementation Blockers:**
    - If you discover that the failure is caused by a bug or missing logic in the **application code** (rather than the test):
        1. **Stop** further implementation of this scenario.
        2. Mark the scenario as `incomplete` in your internal tracking.
        3. Write a clear comment in the task history: `"During implementation, I found an issue in the code please review: [Detailed description of the bug/blocker]"`.
        4. **Quit** the task processing for this specific scenario.

## 3. Completion and Reporting

After all scenarios have been processed (either completed or marked as blocked):

- **Create file with report:** `/app/tmp/{{task-key}}_report.md`
- **Jira Documentation:** Leave a detailed comment on the Jira issue summarizing your work, results, and any blockers found. Always include the branch name where the test was created.
```bash
jira-ai add-comment --file-path /app/tmp/{{task-key}}_report.md --issue-key {{task-key}}
```
- **Delete comment file:** delete `/app/tmp/{{task-key}}_report.md`

### 4. Add "pr_created" label to task
```bash
jira-ai add-label-to-issue {{task-key}} pr_created
```

### 5. Push created branch to remote
```bash
git push -u origin tests/{{task-key}}
```

---
## ⚠️ Hard rules — DO NOT violate

**Do NOT touch `.git` in any way that changes history or remotes.** The repo at `/app/repo` is pre-cloned by the orchestration script with the correct `origin` remote and authenticated `GH_TOKEN`. The following commands are forbidden inside this workflow:

- `git init`
- `rm -rf .git`
- `git remote remove origin` / `git remote rm origin`
- `git remote set-url origin ...` to anything other than the existing URL
- `git filter-branch`, `git filter-repo`, `git reset --hard` to a commit before the clone point

Allowed git commands: `git checkout -b`, `git add`, `git commit`, `git push -u origin <branch>`, `git status`, `git diff`, `git log`.

**Do NOT hardcode secrets in source files.** Admin credentials, Stripe keys, API tokens — read all of these from `process.env.*` in `tests/helpers/environment-config.ts`. If a value isn't already in `EnvironmentConfig`, add it as an env var reference, do not paste the literal. Example:

```ts
// ❌ NEVER
export const ADMIN_EMAIL = "admin@revyoos.com";
// ✅ ALWAYS
export const ADMIN_EMAIL = process.env.ADMIN_EMAIL ?? "";
```

**Do NOT use weak assertions for visual/computed state.** For color changes, status indicators, or any "did the value change" check, assert the actual value:

```ts
// ❌ weak — passes for any non-empty string
expect(statusText).toBeTruthy();
// ✅ exact — compare the exact visible label
expect(statusText).toBe("Connected");
```

---
## Important parts of the project

- **Page Objects** live in `tests/pages/`. Read every file in that directory before writing tests.
- **Fixtures** live in `tests/fixtures/`. The `authenticatedPage` fixture handles login + exposes `apiHelper`. Use it instead of writing login code per test.
- **Helpers** live in `tests/helpers/`. Common patterns: `TestDataBuilder` for unique data, `ApiHelper` for backend REST calls, `PropertyHelper` for combined UI+API property flows.

---

# Handling Test Data in E2E Tests

## The Problem
Creating real properties and booking channel connections in the environment requires valid OTA credentials and may trigger external sync processes. Avoid creating excessive test data that cannot be cleaned up.

## The Solution: Persistent Test Properties
Use a pool of pre-created test properties. These properties are created once and reused across test runs.

## ⚠️ Important: UI vs API Usage
- **Creation must happen via the UI.**
- **Deletion must happen via the UI.**
- **Resets and state cleanup can happen via the API** (to speed up setup/teardown).

## Implementation Details

### 1. Ensuring the Property Exists
Every test using a persistent property should start by ensuring the property exists:
```typescript
await propertyHelper.ensurePropertyExists(testPropertyId);
```

### 2. Resetting to Default State
Reset the property to a clean state before each test:
```typescript
await propertyHelper.resetPropertyToDefault(testPropertyId);
```

### 3. For Authenticated Tests
Use the authenticated fixture:
```typescript
import { test, expect } from './fixtures/authenticated.fixture';

test('my test', async ({ page, authenticatedPage }) => {
  const { propertiesPage, apiHelper } = authenticatedPage;
  // User is already logged in
});
```

### Example Test Structure
```typescript
test('should update property name', async ({ page, authenticatedPage }) => {
  const { propertyHelper } = authenticatedPage;

  await test.step('Setup', async () => {
    await propertyHelper.ensurePropertyExists(testPropertyId);
    await propertyHelper.resetPropertyToDefault(testPropertyId);
  });

  await test.step('Action: Update Property Name', async () => {
    // ... test logic
  });
});
```
