# Reviz — AI QA Agent for Revyoos

Reviz is an autonomous AI QA agent that automatically analyzes Jira tickets, prepares test scenarios, and writes Playwright e2e tests for the [Revyoos](https://revyoos.com) platform.

---

## How It Works

Reviz polls Jira for tickets and processes them in four phases, controlled by Jira labels:

```
Jira ticket (status: "Ready For Test", label: "reviz-qa")
        ↓
  Phase 1: analyze-task       → label: "analyzed"
  ⏸ QA answers clarifying questions
        ↓
  Phase 2: test-scenarios     → label: "qaed"
  ⏸ QA selects scenarios to implement
        ↓
  Phase 3: write-tests        → label: "pr_created"
  Phase 4: review-pr (auto)   → merge or retry
        ↓
  Tests pass → PR auto-merged, branch deleted
  Tests fail → labels stripped, ticket re-enters queue from Phase 1
```

**Two human checkpoints** (after Phase 1 and Phase 2). Phase 3/4 runs autonomously — if all tests pass, the PR is auto-merged and the branch is deleted. If tests fail, failing tests are marked with `test.skip`, labels are stripped, and the ticket is transitioned back to "Ready For Test" for automatic reprocessing.

---

## Stack

| Tool | Purpose |
|---|---|
| Docker | Container runtime |
| OpenCode Go | LLM engine (flat-rate subscription) |
| `jira-ai` CLI | Jira integration |
| `playwright-cli` | Browser automation for test validation |
| GitHub API | PR creation |
| Railway | Cloud deployment |

### Models (per step)

| Step | Model |
|---|---|
| analyze-task | `opencode-go/deepseek-v4-flash` |
| test-scenarios | `opencode-go/deepseek-v4-flash` |
| write-tests | `opencode-go/qwen3.6-plus` |
| review-pr | `opencode-go/deepseek-v4-flash` |

Models can be overridden via env vars without rebuilding the image.

---

## Repository Structure

```
reviz/
├── instructions/
│   └── generic/
│       ├── project-description.md      # Revyoos context for the agent
│       ├── analyze-task.md             # Phase 1: task analysis instructions
│       ├── test-scenarios.md           # Phase 2: scenario preparation instructions
│       ├── write-tests.md              # Phase 3: test writing instructions
│       ├── review-pr.md               # Phase 4: auto-review, merge/retry
│       ├── maintenance.md             # Periodic test suite health check
│       └── how-to-use-playwright-cli.md # Browser automation rules & token budget
├── confluence-api.js                   # Confluence page upsert API
├── Dockerfile
├── docker-compose.yml                  # Local dev only
├── entrypoint.sh                       # Startup + auth + run mode selector
├── look-for-tasks.sh                   # Jira polling + opencode orchestration
└── package-lock.json
```

---

## Environment Variables

### Required

| Variable | Description |
|---|---|
| `OPENCODE_API_KEY` | OpenCode Go subscription key (opencode.ai) |
| `GH_TOKEN` | GitHub PAT with `repo` + `workflow` scopes |
| `JIRA_JSON` | Jira credentials as JSON (see below) |

### Repository

| Variable | Default | Description |
|---|---|---|
| `TESTS_REPO_OWNER` | — | GitHub org or user owning the tests repo |
| `TESTS_REPO_NAME` | `revyoos-tests` | Tests repository name |

### Models (optional overrides)

| Variable | Default |
|---|---|
| `OPENCODE_MODEL_ANALYZE` | `opencode-go/deepseek-v4-flash` |
| `OPENCODE_MODEL_WRITE` | `opencode-go/qwen3.6-plus` |
| `OPENCODE_MODEL_REVIEW` | `opencode-go/deepseek-v4-flash` |

### Runtime

| Variable | Default | Description |
|---|---|---|
| `RUN_MODE` | `webhook` | `webhook` / `cron` / `loop` |
| `PORT` | `8080` | HTTP port (Railway sets this automatically) |
| `TRIGGER_SECRET` | — | Optional secret for `X-Reviz-Secret` header |
| `POLL_INTERVAL` | `3600` | Seconds between runs (loop mode only) |
| `GIT_USER_EMAIL` | `reviz-bot@users.noreply.github.com` | Git commit identity |
| `GIT_USER_NAME` | `Reviz Bot` | Git commit identity |

### JIRA_JSON format

```json
{
  "JIRA_BASE_URL": "https://yourcompany.atlassian.net",
  "JIRA_EMAIL": "your@email.com",
  "JIRA_API_TOKEN": "your_jira_api_token"
}
```

Get your Jira API token at: `id.atlassian.com` → Security → API tokens.

---

## Deployment (Railway)

1. Connect this repository to Railway
2. Set all required environment variables in the Railway dashboard
3. Railway builds the Dockerfile and starts the agent in `webhook` mode
4. Trigger manually: `POST /run` with header `X-Reviz-Secret: <your_secret>`
5. Health check: `GET /` → returns `reviz ok — POST /run to trigger`

---

## Local Development

```bash
# Set required env vars
export JIRA_JSON='{"JIRA_BASE_URL":"...","JIRA_EMAIL":"...","JIRA_API_TOKEN":"..."}'
export GH_TOKEN=your_github_token
export OPENCODE_API_KEY=your_opencode_key

# Build and run
docker compose up --build

# Trigger a run
curl -X POST http://localhost:8080/run
```

---

## Jira Workflow Setup

For Reviz to pick up tickets, make sure:

1. Ticket status is `Prep Autotests`
2. Ticket is **assigned to Reviz** (the Jira user running the agent) or adjust the JQL in `look-for-tasks.sh`
3. Labels are managed automatically by Reviz — do not add/remove `analyzed`, `qaed`, `pr_created` manually

---

## Token Budget Rules

Reviz runs on a **5-hour rolling quota window**. To maximize throughput:

- Jira details are pre-fetched once and cached to disk
- Browser snapshots are limited to **2 per session**, always written to file
- Existing Page Objects are reused — no redundant browser exploration
- Max **5 scenarios** per run to avoid quota drain
- No test retries beyond one attempt

See `instructions/generic/how-to-use-playwright-cli.md` for full rules.

---

## Changelog

### 2026-06-20 — Align with ainela workflow (auto-merge, retry mechanism)

**Architecture change:** Removed the manual PR-review checkpoint after Phase 3.
Reviz now auto-merges passing test PRs and deletes the branch (matching Dana's
ainela workflow). On test failure, all phase labels are stripped and the ticket
transitions back to "Ready For Test" for automatic reprocessing from Phase 1.

This reduces the workflow to **two human checkpoints** (after Phase 1 and
Phase 2), down from three. The change was requested by Dana (planning meeting
2026-06-19) and confirmed by Nastya.

Also added:
- **Maintenance mode** (`instructions/generic/maintenance.md`) — periodic test
  suite health check, ported from ainela
- **Test-skip-on-failure** — failing tests are marked with `test.skip` instead
  of being deleted, preserving implementation for debugging
- **Test account guard** — pre-flight checks that test account meets scenario
  preconditions (plan tier, account status)

Reference: `ainela-vs-reviz-analysis.md` in this repo for the full comparison.

---

## Maintained by

QA: Anastasiia Shoshu · Revyoos ASD Team
