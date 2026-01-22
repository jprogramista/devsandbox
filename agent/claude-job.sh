#!/bin/bash
# /usr/local/bin/claude-job.sh

JOB_ID="$1"
PROMPT_INPUT="$2"
SESSION="claude-${JOB_ID}"
LOG_FILE="/var/log/claude-jobs/${JOB_ID}.log"
STATUS_FILE="/var/log/claude-jobs/${JOB_ID}.status"

mkdir -p /var/log/claude-jobs
echo "RUNNING" > "$STATUS_FILE"

# prompt can be send as base64 if multiline not escaped
if [[ "$PROMPT_INPUT" == base64:* ]]; then
    PROMPT=$(echo "${PROMPT_INPUT#base64:}" | base64 -d)
else
    PROMPT="$PROMPT_INPUT"
fi

PROMPT_FILE="/tmp/claude-prompt-${JOB_ID}.txt"
echo "$PROMPT" > "$PROMPT_FILE"

RUNNER_SCRIPT="/tmp/claude-runner-${JOB_ID}.sh"
cat > "$RUNNER_SCRIPT" <<'RUNNER'
#!/bin/bash
LOG_FILE="$1"
STATUS_FILE="$2"
PROMPT_FILE="$3"
JOB_ID="$4"

exec >> "$LOG_FILE" 2>&1

echo "=== Started at $(date -Iseconds) ==="
echo "=== Job ID: $JOB_ID ==="
echo "=== Environment: ==="
echo "  - SHELL: $SHELL"
echo "  - PATH: $PATH"
echo "  - JAVA_HOME: ${JAVA_HOME:-NOT SET}"
echo "  - NVM_DIR: ${NVM_DIR:-NOT SET}"
echo "  - SDKMAN_DIR: ${SDKMAN_DIR:-NOT SET}"
echo "  - Claude: $(which claude 2>/dev/null || echo 'NOT FOUND')"
echo "  - Node: $(which node 2>/dev/null || echo 'NOT FOUND')"
echo "  - Java: $(which java 2>/dev/null || echo 'NOT FOUND')"
echo "=== Prompt: ==="
cat "$PROMPT_FILE"
echo ""
echo "=== Executing... ==="
echo ""

if claude --dangerously-skip-permissions "$(cat "$PROMPT_FILE")"; then
    echo ""
    echo "=== SUCCESS at $(date -Iseconds) ==="
    echo "SUCCESS" > "$STATUS_FILE"
    exit_code=0
else
    exit_code=$?
    echo ""
    echo "=== FAILED at $(date -Iseconds) with exit code $exit_code ==="
    echo "FAILED" > "$STATUS_FILE"
fi

rm -f "$PROMPT_FILE"
exit $exit_code
RUNNER

chmod +x "$RUNNER_SCRIPT"

# important for paths from interactive mode, -l login shell
tmux new-session -d -s "$SESSION" \
    bash -i -l "$RUNNER_SCRIPT" "$LOG_FILE" "$STATUS_FILE" "$PROMPT_FILE" "$JOB_ID"

echo "Started job $JOB_ID in session $SESSION"
echo "Logs: $LOG_FILE"
