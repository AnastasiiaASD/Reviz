# Instruction: Analyze Task

## Objective
Conduct a deep dive into the task requirements by analyzing Jira discussions and the application's current state. Identify missing information and prepare clarifying questions to ensure high-quality test coverage.
Read @/instructions/generic/project-description.md before start
Knowledge base with full feature documentation is at /app/knowledge-base/ — read the relevant feature file before analyzing the task.

## ⛔ Token budget

Opencode-go runs on a 5-hour rolling quota window. This step is meant to be cheap — keep it that way:

- **Do not call `jira-ai task-with-details`.** The orchestrator already pre-fetched it to `/app/tmp/{{task-key}}_details.txt`. Read that file.
- **Do not open a browser unless the task description is genuinely ambiguous about what page to test.** Most analysis can be done from the Jira details alone. If you do open a browser, you are bound by the budget rules in @/instructions/generic/how-to-use-playwright-cli.md (max 2 snapshots, always `--filename`, never bare).

## Workflow

### 1. Analyze Task Context
- **Read cached task details:** `cat /app/tmp/{{task-key}}_details.txt`
- **Browser investigation (only if needed):** Use @/instructions/generic/how-to-use-playwright-cli.md and respect the snapshot budget.

### 2. Generate Questions
- Based on your investigation, identify ambiguities or "happy path" assumptions.
- Generate a list of questions that will help you prepare test cases in the future.

### 3. Post Questions to Jira
- Save your comment with observations and questions to `/app/tmp/{{task-key}}_comment.md`
- Use the following command:
  ```bash
  jira-ai add-comment --file-path /app/tmp/{{task-key}}_comment.md --issue-key {{task-key}}
  ```

### 4. Add "analyzed" label to task
```bash
jira-ai add-label-to-issue {{task-key}} analyzed
```

### 5. Assign task to QA Anastasiia Shoshu
```bash
jira-ai issue assign {{task-key}} "712020:f5e4ea9b-86f3-42d8-9a02-b35dfd8f01bc"
```
### 6. Wait for QA confirmation
After assigning the task, stop. Do NOT proceed to test scenarios.
**Wait for Anastasiia Shoshu to confirm the analysis is correct 
before the task moves forward.**
