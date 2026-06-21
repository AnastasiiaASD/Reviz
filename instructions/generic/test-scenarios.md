# Instruction: Prepare and Validate Test Scenarios

## Goal
Analyze the task requirements, define comprehensive test scenarios (happy path and negative), manually validate them in the browser, and document technical details for future automation.
Read @/instructions/generic/project-description.md before start.
Knowledge base with full feature documentation is at /app/knowledge-base/ — read the relevant feature file before analyzing the task.

## ⛔ Token budget

Opencode-go has a 5-hour rolling quota window. Keep this step lean:

- **Do not call `jira-ai task-with-details`.** The orchestrator already cached it at `/app/tmp/{{task-key}}_details.txt`. Read that file.
- **Browser exploration is bound by @/instructions/generic/how-to-use-playwright-cli.md** — max 2 snapshots, always `--filename`, never bare.
- One scenario at a time, and **stop after 5 scenarios** even if more are defined — bigger batches blow the budget and the PM can re-trigger for the rest.

## Before start
- **Read cached task details:** `cat /app/tmp/{{task-key}}_details.txt`

## Workflow

### 1. Analysis and Scenario Preparation
Define a list of test scenarios categorized into:
- **Happy Path:** Successful execution of the main feature/fix.
- **Negative Tests:** Handling of invalid inputs, edge cases, and error states.

### 2. Iterative Validation and Data Collection
- Process scenarios **one by one**. For each scenario:
    1. **Execute:** Use @/instructions/generic/how-to-use-playwright-cli.md to manually validate the behavior (respect the snapshot budget).
    2. **Collect:** Identify and collect:
        - **Selectors:** Unique CSS or Playwright-compatible selectors for all interactive elements.
        - **Data Requirements:** Specific input values or state requirements.
        - **Verification Points:** What specific UI elements or behaviors confirm the test passed.
    3. **Save Immediately:** Append these technical details to `/app/tmp/{{task-key}}_comment.md` before starting the next scenario. Ensure this data is clear enough to be used directly for autotest creation.
    4. **Expected File Structure:** Markdown table with columns: Number | Scenario name | Scenario Details | Result. After the table add a `### Additional tech details` paragraph to save useful technical information that can be used for creation of e2e tests.

### 3. Post scenarios to Jira comment

Save scenarios table to `/app/tmp/{{task-key}}_scenarios.md` and post:

```bash
jira-ai add-comment --file-path /app/tmp/{{task-key}}_scenarios.md --issue-key {{task-key}}
```

### 4. Add label
```bash
jira-ai add-label-to-issue {{task-key}} scenarios-done
```

### 5. Assign back to QA
```bash
jira-ai issue assign {{task-key}} "712020:f5e4ea9b-86f3-42d8-9a02-b35dfd8f01bc"
```
