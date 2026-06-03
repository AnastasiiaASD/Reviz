#!/bin/bash

# Script to get all tasks assigned to the current user from Jira-ai
# If a task is found, run opencode with the appropriate instruction file.

# Tests repo configuration (override via env)
TESTS_REPO_OWNER="${TESTS_REPO_OWNER:-[GITHUB_ORG_OR_USER]}"
TESTS_REPO_NAME="${TESTS_REPO_NAME:-revyoos-qa-automation}"

if [ -z "$GH_TOKEN" ]; then
    echo "ERROR: GH_TOKEN env var is not set — cannot clone or push to ${TESTS_REPO_OWNER}/${TESTS_REPO_NAME}" >&2
    exit 1
fi

TESTS_REPO_URL="https://x-access-token:${GH_TOKEN}@github.com/${TESTS_REPO_OWNER}/${TESTS_REPO_NAME}.git"

# --- Model selection (set in entrypoint.sh; safe fallbacks here) -----------
: "${OPENCODE_MODEL_ANALYZE:=opencode-go/deepseek-v4-flash}"
: "${OPENCODE_MODEL_WRITE:=opencode-go/qwen3.6-plus}"
: "${OPENCODE_MODEL_REVIEW:=opencode-go/deepseek-v4-flash}"

# --- Pre-fetch Jira details to a file so all three opencode runs read from
#     disk instead of each one calling `jira-ai task-with-details` again.
#     Saves ~1 tool round-trip per opencode session => 3 saved turns/ticket.
# Path: /app/tmp/{TASK_ID}_details.txt (referenced as @/tmp/... in prompts).
prefetch_task_details() {
    local task_id="$1"
    mkdir -p /app/tmp
    local out="/app/tmp/${task_id}_details.txt"
    if jira-ai task-with-details "$task_id" > "$out" 2>/dev/null; then
        echo "Cached Jira details for $task_id -> $out ($(wc -c < "$out") bytes)"
    else
        echo "WARN: jira-ai task-with-details $task_id failed; opencode will fetch live" >&2
        rm -f "$out"
    fi
}

echo "Checking for assigned tasks (First pass: Analysis)..."
OUTPUT=$(jira-ai run-jql "assignee = currentUser() AND status = 'Ready For Test' AND (labels IS EMPTY OR (labels != analyzed AND labels != qaed))" --limit 1)

# Extract Task ID (Key) from the output table
TASK_ID=$(echo "$OUTPUT" | grep "│" | grep -v "Key" | awk -F '│' '{print $2}' | tr -d '[:space:]')

if [ -n "$TASK_ID" ]; then
    echo "Task $TASK_ID found for analysis! (model: $OPENCODE_MODEL_ANALYZE)"
    prefetch_task_details "$TASK_ID"
    opencode run "Please run @/instructions/analyze-task.md for the task $TASK_ID. Jira details are cached at /app/tmp/${TASK_ID}_details.txt — read that file instead of calling jira-ai task-with-details again." --model "$OPENCODE_MODEL_ANALYZE"
    rm -f "/app/tmp/${TASK_ID}_details.txt"
else
    echo "No analysis tasks found. Checking for test scenario tasks..."
    OUTPUT=$(jira-ai run-jql "assignee = currentUser() AND status = 'Ready For Test' AND (labels IS EMPTY OR (labels = analyzed AND labels != qaed))" --limit 1)
    TASK_ID=$(echo "$OUTPUT" | grep "│" | grep -v "Key" | awk -F '│' '{print $2}' | tr -d '[:space:]')

    if [ -n "$TASK_ID" ]; then
        echo "Task $TASK_ID found for test scenarios! (model: $OPENCODE_MODEL_ANALYZE)"
        prefetch_task_details "$TASK_ID"
        opencode run "Please run @/instructions/test-scenarios.md for the task $TASK_ID. Jira details are cached at /app/tmp/${TASK_ID}_details.txt — read that file instead of calling jira-ai task-with-details again." --model "$OPENCODE_MODEL_ANALYZE"
        rm -f "/app/tmp/${TASK_ID}_details.txt"
    else
        echo "No scenario tasks found. Checking for write test tasks..."
        OUTPUT=$(jira-ai run-jql "assignee = currentUser() AND status = 'Ready For Test' AND (labels IS EMPTY OR (labels = analyzed AND labels = qaed AND labels != pr_created))" --limit 1)
        TASK_ID=$(echo "$OUTPUT" | grep "│" | grep -v "Key" | awk -F '│' '{print $2}' | tr -d '[:space:]')

        if [ -n "$TASK_ID" ]; then
            echo "Task $TASK_ID found for writing tests! (write model: $OPENCODE_MODEL_WRITE, review model: $OPENCODE_MODEL_REVIEW)"
            prefetch_task_details "$TASK_ID"

            echo "Cleaning up identical branches..."
            CLEANUP_DIR=$(mktemp -d)
            git clone --quiet "$TESTS_REPO_URL" "$CLEANUP_DIR"
            pushd "$CLEANUP_DIR" > /dev/null
            for branch in $(git branch -r | grep 'origin/' | grep -v 'origin/main' | grep -v 'HEAD'); do
                b=${branch#origin/}
                if [ -z "$(git diff origin/main..$branch)" ]; then
                    echo "Deleting identical branch: $b"
                    git push origin --delete "$b" --quiet
                fi
            done
            popd > /dev/null
            rm -rf "$CLEANUP_DIR"
            rm -rf /app/repo
            git clone "$TESTS_REPO_URL" /app/repo
            cd /app/repo && npm install && cd -

            # Symlink /app/repo/instructions → /app/instructions so @/instructions/...
            # resolves correctly regardless of which dir opencode chose.
            ln -sfn /app/instructions /app/repo/instructions

            (cd /app && opencode run "Please run @/instructions/write-tests.md for the task $TASK_ID. Jira details are cached at /app/tmp/${TASK_ID}_details.txt — read that file instead of calling jira-ai task-with-details again." --model "$OPENCODE_MODEL_WRITE")

            # --- Push branch + create PR ------------------------------------
            BRANCH="tests/${TASK_ID}"
            pushd /app/repo > /dev/null
            if git remote get-url origin >/dev/null 2>&1; then
                git remote set-url origin "$TESTS_REPO_URL"
            else
                echo "WARN: origin remote was missing in /app/repo — re-adding it" >&2
                git remote add origin "$TESTS_REPO_URL"
            fi

            if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
                git push -u origin "$BRANCH"

                PR_PAYLOAD=$(printf '{"title":"%s: автотести","head":"%s","base":"main","body":"Auto-generated by Reviz for %s"}' \
                    "$TASK_ID" "$BRANCH" "$TASK_ID")
                echo "Creating PR for $BRANCH..."
                curl -sS -o /tmp/pr_response.json -w "PR API HTTP %{http_code}\n" \
                    -X POST \
                    -H "Authorization: token ${GH_TOKEN}" \
                    -H "Accept: application/vnd.github+json" \
                    "https://api.github.com/repos/${TESTS_REPO_OWNER}/${TESTS_REPO_NAME}/pulls" \
                    -d "$PR_PAYLOAD" || echo "WARN: PR creation curl failed"
                jq -r '.html_url // .message // empty' /tmp/pr_response.json 2>/dev/null || cat /tmp/pr_response.json
                rm -f /tmp/pr_response.json
            else
                echo "ERROR: opencode did not create branch ${BRANCH} — skipping push/PR" >&2
            fi
            popd > /dev/null

            # Review step
            (cd /app && opencode run "Please run @/instructions/review-pr.md for the task $TASK_ID. Jira details are cached at /app/tmp/${TASK_ID}_details.txt — read that file instead of calling jira-ai task-with-details again." --model "$OPENCODE_MODEL_REVIEW")
            rm -f "/app/tmp/${TASK_ID}_details.txt"

            # Final push in case the review step made commits on the branch.
            pushd /app/repo > /dev/null
            if git remote get-url origin >/dev/null 2>&1 && git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
                git push origin "$BRANCH" || true
            fi
            popd > /dev/null

            rm -rf /app/repo
        else
            echo "No write test tasks found."
        fi
    fi
fi
