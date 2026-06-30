#!/bin/bash
set -e

# --- Jira AI auth ----------------------------------------------------------
if [ -n "$JIRA_JSON" ]; then
    echo "Configuring Jira AI..."
    echo "$JIRA_JSON" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' > .env
    jira-ai auth --from-file .env || echo "WARN: Jira auth failed — will retry on task run" >&2
    rm .env
    echo "Jira AI configured successfully."
else
    echo "WARNING: JIRA_JSON env var is not set — Jira polling will fail." >&2
fi

if [ -z "$CONFLUENCE_SPACE_KEY" ]; then
    echo "WARNING: CONFLUENCE_SPACE_KEY not set — Confluence pages will not be created." >&2
fi

# --- Git identity (needed for commits made by Reviz) ---------------------
git config --global user.email "${GIT_USER_EMAIL:-reviz-bot@users.noreply.github.com}"
git config --global user.name "${GIT_USER_NAME:-Reviz Bot}"

# --- Clone knowledge base ------------------------------------------
echo "Cloning revyoos-knowledge-base..."
if [ -n "$GH_TOKEN" ]; then
  git clone --quiet \
    "https://x-access-token:${GH_TOKEN}@github.com/AnastasiiaASD/revyoos-knowledge-base.git" \
    /app/knowledge-base 2>/dev/null \
    && echo "Knowledge base ready: $(ls /app/knowledge-base/*.md | wc -l) files" \
    || echo "WARN: knowledge-base clone failed" >&2
else
  echo "WARN: GH_TOKEN not set — knowledge-base unavailable" >&2
fi
# --- Opencode permissions --------------------------------------------------
cat <<EOF > /app/opencode.json
{
  "permission": {
    "*": {
      "*": "allow"
    }
  }
}
EOF

# --- Opencode model selection (per-step, quota-aware) ----------------------
# Opencode-go quota: 5-hour rolling window.
#
# Model split by workload:
#   - analyze step:     short prompts, no code gen     -> cheap/flash tier
#   - write-tests step: heavy code gen + inspection    -> stronger tier
#   - review step:      reads diffs, runs tests        -> cheap/flash tier
#
# Available on opencode-go: kimi-k2.5, kimi-k2.6, glm-5, glm-5.1,
#   mimo-v2.5-pro, mimo-v2.5, minimax-m2.5, minimax-m2.7, qwen3.5-plus,
#   qwen3.6-plus, deepseek-v4-pro, deepseek-v4-flash
# If a slug errors with "unknown model", check `opencode models` and update
# env vars in Railway — no rebuild needed.
export OPENCODE_MODEL_ANALYZE="${OPENCODE_MODEL_ANALYZE:-opencode-go/deepseek-v4-flash}"
export OPENCODE_MODEL_WRITE="${OPENCODE_MODEL_WRITE:-opencode-go/deepseek-v4-pro}"
export OPENCODE_MODEL_REVIEW="${OPENCODE_MODEL_REVIEW:-opencode-go/deepseek-v4-flash}"
# Legacy single-model fallback
export OPENCODE_MODEL="${OPENCODE_MODEL:-$OPENCODE_MODEL_WRITE}"
echo "Opencode models: analyze=$OPENCODE_MODEL_ANALYZE write=$OPENCODE_MODEL_WRITE review=$OPENCODE_MODEL_REVIEW"

# --- Opencode auth (OpenCode Go subscription) ------------------------------
if [ -n "$OPENCODE_API_KEY" ]; then
    echo "Configuring opencode auth for opencode-go provider..."
    AUTH_JSON=$(cat <<EOF
{
  "opencode-go": {
    "type": "api",
    "key": "${OPENCODE_API_KEY}"
  }
}
EOF
)
    for dir in /root/.local/share/opencode /root/.config/opencode /root/.opencode; do
        mkdir -p "$dir"
        echo "$AUTH_JSON" > "$dir/auth.json"
    done
    echo "Opencode auth file written."
else
    echo "WARNING: OPENCODE_API_KEY is not set — opencode-go provider will not auth and calls will fall back to metered glm-5.1." >&2
fi

# --- Run command -----------------------------------------------------------
# RUN_MODE selects behavior (env var, default = webhook):
#   webhook — HTTP server on $PORT; POST /run fires look-for-tasks.sh
#   cron    — run look-for-tasks.sh once, then exit (for Railway Cron jobs)
#   loop    — legacy polling every $POLL_INTERVAL seconds
# Any explicit command arg (e.g. `docker run … bash`) is exec'd as-is.

RUN_MODE="${RUN_MODE:-webhook}"
LOCK_FILE="/tmp/reviz-task.lock"

# Wrap look-for-tasks.sh in flock so concurrent triggers don't clobber /app/repo.
run_task_locked() {
    flock -n 9 || { echo "Another task run is in progress, skipping."; return 0; }
    /app/look-for-tasks.sh || echo "look-for-tasks.sh exited non-zero, continuing..."
} 9>"$LOCK_FILE"

# Local dev / one-off: `docker run ... bash` → exec it.
if [ "$#" -gt 0 ] && [ "$1" != "bash" ]; then
    exec "$@"
fi
if [ "$#" -gt 0 ] && [ "$1" = "bash" ]; then
    exec bash
fi

case "$RUN_MODE" in
    cron)
        echo "Reviz: cron mode — single run."
        run_task_locked
        ;;

    loop)
        echo "Reviz: loop mode (interval: ${POLL_INTERVAL:-3600}s)."
        while true; do
            run_task_locked
            sleep "${POLL_INTERVAL:-3600}"
        done
        ;;

    webhook|*)
        : "${PORT:=8080}"
        export PORT
        echo "Reviz: webhook mode on :$PORT"
        echo "  GET  /     → health check"
        echo "  POST /run  → trigger look-for-tasks.sh"
        echo "  Set TRIGGER_SECRET to require header 'X-Reviz-Secret: <value>'"
        exec python3 -u - <<'PYEOF'
import os, subprocess, threading
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT   = int(os.environ.get("PORT", "8080"))
SECRET = os.environ.get("TRIGGER_SECRET", "")

def run_task():
    try:
        subprocess.run(
            ["flock", "-n", "/tmp/reviz-task.lock", "/app/look-for-tasks.sh"],
            check=False,
        )
    except Exception as e:
        print(f"task runner error: {e}", flush=True)

class H(BaseHTTPRequestHandler):
    def _reply(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body.encode())

    def do_GET(self):
        self._reply(200, "reviz ok — POST /run to trigger\n")

    def do_POST(self):
        if self.path != "/run":
            self._reply(404, "not found\n"); return
        if SECRET and self.headers.get("X-Reviz-Secret") != SECRET:
            self._reply(401, "unauthorized\n"); return
        threading.Thread(target=run_task, daemon=True).start()
        self._reply(202, "triggered\n")

    def log_message(self, fmt, *args):
        print(f"[http] {self.address_string()} - {fmt % args}", flush=True)

print(f"listening on 0.0.0.0:{PORT}", flush=True)
HTTPServer(("0.0.0.0", PORT), H).serve_forever()
PYEOF
        ;;
esac
