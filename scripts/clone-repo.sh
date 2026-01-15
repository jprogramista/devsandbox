#!/bin/bash
# =============================================================================
# CLONE REPO - Safely cloning a repository to a sandbox
# =============================================================================
# Usage:
#   clone-repo.sh <git-url> [branch] [directory-name]
#
# Examples:
#   clone-repo.sh https://github.com/user/repo.git
#   clone-repo.sh https://github.com/user/repo.git develop
#   clone-repo.sh https://github.com/user/repo.git main my-project
# =============================================================================

set -e

REPO_URL="${1:-}"
BRANCH="${2:-main}"
DIR_NAME="${3:-repo}"
WORKSPACE="/workspace"

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=============================================="
echo "  CLONE REPO - Sandbox Safe Clone"
echo -e "==============================================${NC}"

# Check the parameters
if [ -z "$REPO_URL" ]; then
    echo -e "${RED}Error: Repository URL is required${NC}"
    echo ""
    echo "Usage: clone-repo.sh <git-url> [branch] [directory-name]"
    echo ""
    echo "Examples:"
    echo "  clone-repo.sh https://github.com/user/repo.git"
    echo "  clone-repo.sh https://github.com/user/repo.git develop"
    echo "  clone-repo.sh git@github.com:user/repo.git main my-project"
    exit 1
fi

TARGET_DIR="$WORKSPACE/$DIR_NAME"

# Warning if directory exists
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}Warning: Directory $TARGET_DIR already exists!${NC}"
    read -p "Remove and re-clone? (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo "Removing existing directory..."
        rm -rf "$TARGET_DIR"
    else
        echo "Aborting."
        exit 1
    fi
fi

echo ""
echo "Repository: $REPO_URL"
echo "Branch:     $BRANCH"
echo "Target:     $TARGET_DIR"
echo ""

# Cloning
echo "Cloning repository..."
git clone --branch "$BRANCH" --single-branch --depth 1 "$REPO_URL" "$TARGET_DIR"

# Set permissions
chown -R developer:developer "$TARGET_DIR"

echo ""
echo -e "${GREEN}✓ Repository cloned successfully!${NC}"
echo ""
echo "Next steps:"
echo "  cd $TARGET_DIR"
echo ""

# Check project type
if [ -f "$TARGET_DIR/build.gradle" ] || [ -f "$TARGET_DIR/build.gradle.kts" ]; then
    echo -e "${GREEN}Detected: Gradle project${NC}"
    echo "  ./gradlew build"
    echo "  ./gradlew bootRun --args='--spring.profiles.active=dev'"
fi

if [ -f "$TARGET_DIR/pom.xml" ]; then
    echo -e "${GREEN}Detected: Maven project${NC}"
    echo "  mvn clean install"
    echo "  mvn spring-boot:run -Dspring-boot.run.profiles=dev"
fi

if [ -f "$TARGET_DIR/package.json" ]; then
    echo -e "${GREEN}Detected: Node.js project${NC}"
    echo "  npm install"
    echo "  npm run start"
fi

if [ -d "$TARGET_DIR/ui" ] && [ -f "$TARGET_DIR/ui/package.json" ]; then
    echo -e "${GREEN}Detected: Frontend in /ui${NC}"
    echo "  cd ui && npm install && npm run start"
fi

if [ -f "$TARGET_DIR/requirements.txt" ]; then
    echo -e "${GREEN}Detected: Python project${NC}"
    echo "  pip install -r requirements.txt"
fi

echo ""
