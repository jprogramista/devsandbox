#!/bin/bash

# Usage: ./claude-worktree.sh create feature-name "Task description"
#        ./claude-worktree.sh cleanup feature-name

ACTION=$1
FEATURE=$2
TASK=$3

WORKTREE_DIR=".worktrees"
BRANCH_PREFIX="feature"

# Auto-detect main branch (main or master)
detect_main_branch() {
  if git show-ref --verify --quiet refs/heads/main; then
    echo "main"
  elif git show-ref --verify --quiet refs/heads/master; then
    echo "master"
  else
    # Fallback: check remote
    if git ls-remote --heads origin main 2>/dev/null | grep -q main; then
      echo "main"
    elif git ls-remote --heads origin master 2>/dev/null | grep -q master; then
      echo "master"
    else
      echo "main"  # Default fallback
    fi
  fi
}

# Check if remote origin exists
has_remote_origin() {
  git remote | grep -q "^origin$"
  return $?
}

MAIN_BRANCH=$(detect_main_branch)
HAS_ORIGIN=$(has_remote_origin && echo "true" || echo "false")

case $ACTION in
  create)
    echo "Creating worktree for: $FEATURE"
    echo "Using main branch: $MAIN_BRANCH"

    if [ "$HAS_ORIGIN" = "true" ]; then
      echo "Remote origin detected - syncing with remote"
      # Ensure main is up to date
      git checkout "$MAIN_BRANCH"
      git pull origin "$MAIN_BRANCH"
    else
      echo "No remote origin - working locally only"
      git checkout "$MAIN_BRANCH"
    fi

    # Create worktree
    git worktree add "$WORKTREE_DIR/$FEATURE" -b "$BRANCH_PREFIX/$FEATURE"

    # Navigate and start Claude
    cd "$WORKTREE_DIR/$FEATURE"

    if [ -n "$TASK" ]; then
      echo "Starting Claude with task: $TASK"
      claude "$TASK"
    else
      claude
    fi
    ;;

  commit)
    echo "Committing changes in: $FEATURE"
    cd "$WORKTREE_DIR/$FEATURE"

    git add .
    git commit -m "${3:-Update $FEATURE}"

    if [ "$HAS_ORIGIN" = "true" ]; then
      echo "Pushing to remote origin..."
      git push origin "$BRANCH_PREFIX/$FEATURE"
    else
      echo "No remote origin - committed locally only"
    fi
    ;;

  cleanup)
    echo "Cleaning up worktree: $FEATURE"

    # Go to main repo
    cd $(git rev-parse --show-toplevel)

    # Remove worktree
    git worktree remove "$WORKTREE_DIR/$FEATURE" --force

    # Delete local branch
    git branch -D "$BRANCH_PREFIX/$FEATURE"

    # Optional: delete remote branch
    if [ "$HAS_ORIGIN" = "true" ]; then
      read -p "Delete remote branch? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin --delete "$BRANCH_PREFIX/$FEATURE"
      fi
    else
      echo "No remote origin - local branch deleted only"
    fi
    ;;

  list)
    git worktree list
    ;;

  prune)
    echo "Pruning stale worktrees..."
    git worktree prune -v
    ;;

  status)
    echo "Main branch: $MAIN_BRANCH"
    echo "Remote origin: $([ "$HAS_ORIGIN" = "true" ] && echo "Yes" || echo "No")"
    if [ "$HAS_ORIGIN" = "true" ]; then
      echo "Remote URL: $(git remote get-url origin)"
    fi
    echo ""
    echo "Active worktrees:"
    git worktree list
    echo ""
    echo "Local feature branches:"
    git branch | grep "$BRANCH_PREFIX/" || echo "  (none)"
    ;;

  *)
    echo "Usage:"
    echo "  $0 create <feature-name> [task description]"
    echo "  $0 commit <feature-name> [commit message]"
    echo "  $0 cleanup <feature-name>"
    echo "  $0 list"
    echo "  $0 prune"
    echo "  $0 status"
    echo ""
    echo "Examples:"
    echo "  $0 create api-auth 'Implement JWT authentication'"
    echo "  $0 commit api-auth 'feat: add JWT endpoints'"
    echo "  $0 cleanup api-auth"
    ;;
esac