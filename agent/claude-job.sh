#!/bin/bash
# /usr/local/bin/claude-job.sh

JOB_ID="$1"
PROMPT_INPUT="$2"
SESSION="claude-${JOB_ID}"
LOG_FILE="/var/log/claude-jobs/${JOB_ID}.log"
STATUS_FILE="/var/log/claude-jobs/${JOB_ID}.status"

# Worktree configuration - use current directory as main repo
MAIN_REPO="$(pwd)"
WORKTREE_BASE="${MAIN_REPO}/.worktrees"
WORKTREE_PATH="${WORKTREE_BASE}/${JOB_ID}"
BRANCH_NAME="claude/job-${JOB_ID}"

# Verify we're in a git repository
if [ ! -d "${MAIN_REPO}/.git" ]; then
    echo "ERROR: Current directory is not a git repository"
    echo "Please run this script from a git repository root"
    exit 1
fi

mkdir -p /var/log/claude-jobs
mkdir -p "$WORKTREE_BASE"
echo "RUNNING" > "$STATUS_FILE"

# Decode prompt
if [[ "$PROMPT_INPUT" == base64:* ]]; then
    PROMPT=$(echo "${PROMPT_INPUT#base64:}" | base64 -d)
else
    PROMPT="$PROMPT_INPUT"
fi

PROMPT_FILE="/tmp/claude-prompt-${JOB_ID}.txt"

# Prepare prompt with worktree info
cat > "$PROMPT_FILE" <<EOF
IMPORTANT SETUP INSTRUCTIONS:
1. You are working in an isolated git worktree at: ${WORKTREE_PATH}
2. Your branch name is: ${BRANCH_NAME}
3. When done, create PR using: gh pr create --base main --head ${BRANCH_NAME} --fill
4. The worktree will be automatically cleaned up after the job

USER TASK:
$PROMPT
EOF

RUNNER_SCRIPT="/tmp/claude-runner-${JOB_ID}.sh"
cat > "$RUNNER_SCRIPT" <<'RUNNER'
#!/bin/bash
LOG_FILE="$1"
STATUS_FILE="$2"
PROMPT_FILE="$3"
JOB_ID="$4"
MAIN_REPO="$5"
WORKTREE_PATH="$6"
BRANCH_NAME="$7"

exec >> "$LOG_FILE" 2>&1

echo "=== Started at $(date -Iseconds) ==="
echo "=== Job ID: $JOB_ID ==="

# Setup worktree
echo "=== Setting up worktree ==="
cd "$MAIN_REPO" || exit 1

# Fetch latest changes
git fetch origin main

# Create worktree with new branch based on latest main
if git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" origin/main; then
    echo "✓ Worktree created at $WORKTREE_PATH"
else
    echo "✗ Failed to create worktree"
    echo "FAILED" > "$STATUS_FILE"
    exit 1
fi

# Change to worktree directory
cd "$WORKTREE_PATH" || exit 1

echo "=== Environment: ==="
echo "  - Main repo: $MAIN_REPO"
echo "  - Working directory: $(pwd)"
echo "  - Git branch: $(git branch --show-current)"
echo "  - SHELL: $SHELL"
echo "  - Claude: $(which claude 2>/dev/null || echo 'NOT FOUND')"
echo "=== Prompt: ==="
cat "$PROMPT_FILE"
echo ""
echo "=== Executing... ==="
echo ""

# Execute Claude
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

# Cleanup worktree
echo "=== Cleaning up worktree ==="
cd "$MAIN_REPO"
git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || rm -rf "$WORKTREE_PATH"

# If failed and branch exists, optionally clean it up
if [ $exit_code -ne 0 ]; then
    git branch -D "$BRANCH_NAME" 2>/dev/null || true
fi

rm -f "$PROMPT_FILE"
exit $exit_code
RUNNER

chmod +x "$RUNNER_SCRIPT"

# Start in tmux with worktree parameters
tmux new-session -d -s "$SESSION" \
    bash -i -l "$RUNNER_SCRIPT" "$LOG_FILE" "$STATUS_FILE" "$PROMPT_FILE" "$JOB_ID" \
    "$MAIN_REPO" "$WORKTREE_PATH" "$BRANCH_NAME"

echo "Started job $JOB_ID in session $SESSION"
echo "Main repo: $MAIN_REPO"
echo "Branch: $BRANCH_NAME"
echo "Worktree: $WORKTREE_PATH"
echo "Logs: $LOG_FILE"