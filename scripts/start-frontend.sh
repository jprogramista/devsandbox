#!/bin/bash
# =============================================================================
# START FRONTEND - Running Angular/Node with Debug
# =============================================================================
# Usage:
#   start-frontend.sh [project-dir] [port]
#
# Examples:
#   start-frontend.sh                      # /workspace/repo/ui, port 4200
#   start-frontend.sh /workspace/repo/ui   # custom directory
#   start-frontend.sh /workspace/app 3000  # custom port
# =============================================================================

# Load nvm for Node/npm
if [ -f "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
fi

set -e

PROJECT_DIR="${1:-/workspace/repo/ui}"
PORT="${2:-4200}"
DEBUG_PORT=9229

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=============================================="
echo "  START FRONTEND - Angular/Node + Debug"
echo -e "==============================================${NC}"
echo ""
echo "Project:     $PROJECT_DIR"
echo "Port:        $PORT"
echo "Debug Port:  $DEBUG_PORT"
echo ""

cd "$PROJECT_DIR"

# Check if there are node_modules
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}node_modules not found. Running npm install...${NC}"
    npm install
    echo ""
fi

# Detect project type
if [ -f "angular.json" ]; then
    echo -e "${GREEN}Detected: Angular project${NC}"
    echo ""
    
    # Angular with debug
    # --host 0.0.0.0 allows connections from the host
    ng serve \
        --host 0.0.0.0 \
        --port "$PORT" \
        --disable-host-check \
        --poll 2000
        
elif [ -f "next.config.js" ] || [ -f "next.config.mjs" ]; then
    echo -e "${GREEN}Detected: Next.js project${NC}"
    echo ""
    
    # Next.js with debug
    NODE_OPTIONS="--inspect=0.0.0.0:${DEBUG_PORT}" npm run dev -- -p "$PORT" -H 0.0.0.0
    
elif [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
    echo -e "${GREEN}Detected: Vite project${NC}"
    echo ""
    
    npm run dev -- --host 0.0.0.0 --port "$PORT"
    
elif grep -q "react-scripts" package.json 2>/dev/null; then
    echo -e "${GREEN}Detected: Create React App${NC}"
    echo ""
    
    PORT="$PORT" HOST=0.0.0.0 npm start
    
elif grep -q "\"start\"" package.json 2>/dev/null; then
    echo -e "${GREEN}Using npm start...${NC}"
    echo ""
    
    # Generic Node with debug
    NODE_OPTIONS="--inspect=0.0.0.0:${DEBUG_PORT}" npm start
    
else
    echo -e "${YELLOW}No recognized frontend framework found!${NC}"
    echo "Available scripts in package.json:"
    cat package.json | jq '.scripts' 2>/dev/null || cat package.json | grep -A20 '"scripts"'
    exit 1
fi
