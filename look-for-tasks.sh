#!/bin/bash

TESTS_REPO_OWNER="${TESTS_REPO_OWNER:-AnastasiiaASD}"
TESTS_REPO_NAME="${TESTS_REPO_NAME:-revyoos-qa-automation}"

if [ -z "$GH_TOKEN" ]; then
    echo "ERROR: GH_TOKEN not set" >&2; exit 1
fi

TESTS_REPO_URL="https://x-access-token:${GH_TOKEN}@github.com/${TESTS_REPO_OWNER}/${TESTS_REPO_NAME}.git"

: "${OPENCODE_MODEL_ANALYZE:=opencode-go/deepseek-v4-flash}"
: "${OPENCODE_MODEL_WRITE:=opencode-go/qwen3.6-plus}"

prefetch_task_details() {
    local task_id="$1"
    mkdir -p /app/tmp
    local out="/app/tmp/${task_id}_details.txt"
    if jira-ai task-with-details "$task_id" > "$out" 2>/dev/null; then
        echo "Cached: $out ($(wc -c < "$out") bytes)"
    else
        echo "WARN: prefetch failed for $task_id" >&2; rm -f "$out"
    fi
}

# ── Phase 1: analyze ────────────────────────────────────────────────────────
echo "=== Phase 1: analyze ==="
OUTPUT=$(jira-ai run-jql "assignee = currentUser() AND status = 'Prep Autotests' AND labels NOT IN (analyzed)" --limit 1)
TASK_ID=$(echo "$OUTPUT" | grep "│" | grep -v "Key" | awk -F '│' '{print $2}' | tr -d '[:space:]')

if [ -n "$TASK_ID" ]; then
    echo "→ $TASK_ID (model: $OPENCODE_MODEL_ANALYZE)"
    prefetch_task_details "$TASK_ID"
    opencode run "Please run @/instructions/analyze-task.md for $TASK_ID. Details at /app/tmp/${TASK_ID}_details.txt" \
        --model "$OPENCODE_MODEL_ANALYZE"
    rm -f "/app/tmp/${TASK_ID}_details.txt"
    exit 0
fi

# ── Phase 2: test-scenarios ──────────────────────────────────────────────────
echo "=== Phase 2: test-scenarios ==="
OUTPUT=$(jira-ai run-jql "assignee = currentUser() AND status = 'Prep Autotests' AND labels = analyzed AND labels NOT IN (scenarios-done)" --limit 1)
TASK_ID=$(echo "$OUTPUT" | grep "│" | grep -v "Key" | awk -F '│' '{print $2}' | tr -d '[:space:]')

if [ -n "$TASK_ID" ]; then
    echo "→ $TASK_ID (model: $OPENCODE_MODEL_ANALYZE)"
    prefetch_task_details "$TASK_ID"
    opencode run "Please run @/instructions/test-scenarios.md for $TASK_ID. Details at /app/tmp/${TASK_ID}_details.txt" \
        --model "$OPENCODE_MODEL_ANALYZE"
    rm -f "/app/tmp/${TASK_ID}_details.txt"
    exit 0
fi

# ── Phase 3: write-tests ─────────────────────────────────────────────────────
echo "=== Phase 3: write-tests ==="
OUTPUT=$(jira-ai run-jql "assignee = currentUser() AND status = 'Prep Autotests' AND labels = scenarios-done AND labels NOT IN (pr_created)" --limit 1)
TASK_ID=$(echo "$OUTPUT" | grep "│" | grep -v "Key" | awk -F '│' '{print $2}' | tr -d '[:space:]')

if [ -n "$TASK_ID" ]; then
    echo "→ $TASK_ID (write: $OPENCODE_MODEL_WRITE)"
    prefetch_task_details "$TASK_ID"

    BRANCH="tests/${TASK_ID}"
    LOGFILE="/app/tmp/${TASK_ID}_phase3.log"
    mkdir -p /app/tmp
    : > "$LOGFILE"
    log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"; }

    log "Phase 3 started for $TASK_ID"

    # Клонуємо репо
    rm -rf /app/repo
    log "Cloning $TESTS_REPO_OWNER/$TESTS_REPO_NAME..."
    if ! git clone "$TESTS_REPO_URL" /app/repo 2>>"$LOGFILE"; then
        log "ERROR: git clone failed — marking reviz-blocked"
        jira-ai add-label-to-issue "$TASK_ID" reviz-blocked
        cat > "/app/tmp/${TASK_ID}_pr_comment.md" <<EOF
⚠️ Reviz Phase 3 blocked: git clone failed for $TESTS_REPO_OWNER/$TESTS_REPO_NAME.
Please check GH_TOKEN permissions and repo availability.

— 🤖 Reviz AI Agent
EOF
        jira-ai add-comment --file-path "/app/tmp/${TASK_ID}_pr_comment.md" --issue-key "$TASK_ID"
        rm -f "/app/tmp/${TASK_ID}_pr_comment.md" "/app/tmp/${TASK_ID}_details.txt"
        exit 1
    fi
    cd /app/repo && npm install && cd -
    ln -sfn /app/instructions /app/repo/instructions
    log "Repo cloned and dependencies installed"

    # Запускаємо write-tests
    log "Running opencode write-tests..."
    (cd /app && opencode run "Please run @/instructions/write-tests.md for $TASK_ID. Details at /app/tmp/${TASK_ID}_details.txt" \
        --model "$OPENCODE_MODEL_WRITE")
    log "opencode write-tests finished"

    # Push + PR
    pushd /app/repo > /dev/null
    git remote set-url origin "$TESTS_REPO_URL" 2>/dev/null || git remote add origin "$TESTS_REPO_URL"

    if ! git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
        log "ERROR: branch ${BRANCH} not created by opencode — marking reviz-blocked"
        jira-ai add-label-to-issue "$TASK_ID" reviz-blocked
        cat > "/app/tmp/${TASK_ID}_pr_comment.md" <<EOF
⚠️ Reviz Phase 3 blocked: opencode did not create branch \`${BRANCH}\`.
Check write-tests logs for errors.

— 🤖 Reviz AI Agent
EOF
        jira-ai add-comment --file-path "/app/tmp/${TASK_ID}_pr_comment.md" --issue-key "$TASK_ID"
        rm -f "/app/tmp/${TASK_ID}_pr_comment.md"
        popd > /dev/null
        rm -f "/app/tmp/${TASK_ID}_details.txt"
        rm -rf /app/repo
        exit 1
    fi

    # Step 1: Push branch
    log "Pushing branch $BRANCH..."
    if ! git push -u origin "$BRANCH" 2>>"$LOGFILE"; then
        log "ERROR: git push failed — marking reviz-blocked"
        jira-ai add-label-to-issue "$TASK_ID" reviz-blocked
        cat > "/app/tmp/${TASK_ID}_pr_comment.md" <<EOF
⚠️ Reviz Phase 3 blocked: git push failed for branch \`${BRANCH}\`.
Possible causes: network error, branch conflict, or permission issue.
Branch is available locally for manual push.

— 🤖 Reviz AI Agent
EOF
        jira-ai add-comment --file-path "/app/tmp/${TASK_ID}_pr_comment.md" --issue-key "$TASK_ID"
        rm -f "/app/tmp/${TASK_ID}_pr_comment.md"
        popd > /dev/null
        rm -f "/app/tmp/${TASK_ID}_details.txt"
        rm -rf /app/repo
        exit 1
    fi
    log "Push successful"

    # Step 2: Create PR
    log "Creating PR for $BRANCH..."
    PR_RESPONSE=$(curl -sS \
        -X POST \
        -H "Authorization: token ${GH_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${TESTS_REPO_OWNER}/${TESTS_REPO_NAME}/pulls" \
        -d "{\"title\":\"${TASK_ID}: автотести\",\"head\":\"${BRANCH}\",\"base\":\"main\",\"body\":\"Auto-generated by Reviz for ${TASK_ID}\"}")

    PR_URL=$(echo "$PR_RESPONSE" | grep -o '"html_url":"[^"]*pulls/[0-9]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$PR_URL" ]; then
        log "ERROR: PR creation failed — response: $PR_RESPONSE"
        log "Branch $BRANCH pushed but PR not created — marking reviz-blocked"
        jira-ai add-label-to-issue "$TASK_ID" reviz-blocked
        cat > "/app/tmp/${TASK_ID}_pr_comment.md" <<EOF
⚠️ Reviz Phase 3 partial: branch \`${BRANCH}\` pushed but PR creation failed.
Please create PR manually from branch \`${BRANCH}\` → \`main\`.

— 🤖 Reviz AI Agent
EOF
        jira-ai add-comment --file-path "/app/tmp/${TASK_ID}_pr_comment.md" --issue-key "$TASK_ID"
        rm -f "/app/tmp/${TASK_ID}_pr_comment.md"
        popd > /dev/null
        rm -f "/app/tmp/${TASK_ID}_details.txt"
        rm -rf /app/repo
        exit 1
    fi
    log "PR created: $PR_URL"

    # Step 3: Post Jira comment with PR link
    log "Posting Jira comment with PR link..."
    cat > "/app/tmp/${TASK_ID}_pr_comment.md" <<EOF
🤖 Reviz написав автотести та створив PR: ${PR_URL}
Гілка: \`${BRANCH}\`
Папка тестів: \`tests/${TASK_ID}/\`
GitHub Actions запустить тести автоматично після відкриття PR.

— 🤖 Reviz AI Agent
EOF
    jira-ai add-comment --file-path "/app/tmp/${TASK_ID}_pr_comment.md" --issue-key "$TASK_ID"
    rm -f "/app/tmp/${TASK_ID}_pr_comment.md"
    log "Jira comment posted"

    # Step 4: Set pr_created label (only after successful push + PR)
    log "Setting pr_created label..."
    jira-ai add-label-to-issue "$TASK_ID" pr_created
    log "Phase 3 completed successfully for $TASK_ID"

    popd > /dev/null
    rm -f "/app/tmp/${TASK_ID}_details.txt"
    rm -rf /app/repo
    exit 0
fi

# ── Phase 4: retest ──────────────────────────────────────────────────────────
echo "=== Phase 4: retest ==="
OUTPUT=$(jira-ai run-jql "assignee = currentUser() AND status = 'Ready for Retest' AND labels NOT IN (retested)" --limit 1)
TASK_ID=$(echo "$OUTPUT" | grep "│" | grep -v "Key" | awk -F '│' '{print $2}' | tr -d '[:space:]')

if [ -n "$TASK_ID" ]; then
    echo "→ $TASK_ID (model: $OPENCODE_MODEL_ANALYZE)"
    prefetch_task_details "$TASK_ID"
    opencode run "Please run @/instructions/retest.md for $TASK_ID. Details at /app/tmp/${TASK_ID}_details.txt" \
        --model "$OPENCODE_MODEL_ANALYZE"
    rm -f "/app/tmp/${TASK_ID}_details.txt"
    exit 0
fi

echo "No tasks found in any phase."
