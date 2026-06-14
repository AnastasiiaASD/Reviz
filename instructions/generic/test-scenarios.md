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

### 3. Publish to Confluence

After finalizing all test scenarios, publish them to Confluence:

1. Format the full scenario table as Confluence storage format (XHTML) and write it to `/app/tmp/{{task-key}}_confluence.html`. Extract the Jira host from the `JIRA_JSON` env var (`echo $JIRA_JSON | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.host)"`) to build the ticket link. Use this structure:

   ```html
   <h2>Overview</h2>
   <p>Ticket: <a href="[JIRA_HOST]/browse/{{task-key}}">{{task-key}}</a></p>
   <p>Feature: [feature name from ticket]</p>
   <p>Total scenarios: [N] ([X] happy path, [Y] negative, [Z] edge case)</p>

   <h2>Test Scenarios</h2>
   <table>
     <tr>
       <th>#</th><th>Scenario</th><th>Type</th><th>Steps</th><th>Expected Result</th><th>Severity</th>
     </tr>
     [one &lt;tr&gt; per scenario]
   </table>

   <h2>Notes</h2>
   <p>[any edge cases, env dependencies, or open questions found during browser validation]</p>
   ```

2. Run the following command and capture the printed URL:

   ```bash
   node /app/confluence-api.js upsert "$CONFLUENCE_SPACE_KEY" "[{{task-key}}] Test Scenarios" /app/tmp/{{task-key}}_confluence.html "$CONFLUENCE_PARENT_PAGE_ID"
   ```

   The command prints either `✅ Created: <url>` or `🔄 Updated: <url>` — save the URL for the next step.

### 4. Post Summary to Jira

After the Confluence page is created/updated, write the following short comment to `/app/tmp/{{task-key}}_jira_summary.md` (replace bracketed values with actual counts and the URL from step 3), then post it:

```
📋 Test scenarios documented in Confluence:
[confluence_url]

Summary:
- Total: [N] scenarios
- Happy path: [X]
- Negative: [Y]
- Edge cases: [Z]

Please review the scenarios and reply with ✅ to proceed to Phase 3 (writing Playwright tests).

— 🤖 Reviz AI Agent
```

```bash
jira-ai add-comment --file-path /app/tmp/{{task-key}}_jira_summary.md --issue-key {{task-key}}
```

### 5. Add "qaed" label to task
```bash
jira-ai add-label-to-issue {{task-key}} qaed
```

### 6. Assign task to QA Anastasiia Shoshu
```bash
jira-ai issue assign {{task-key}} "712020:f5e4ea9b-86f3-42d8-9a02-b35dfd8f01bc"
```

### 7. Wait for QA confirmation
After posting scenarios to Jira — stop. Do NOT proceed to writing tests.
**Wait for Anastasiia Shoshu to approve the scenarios before automation begins.**
