#!/bin/bash
# =============================================================================
# START BACKEND - Running Spring Boot with Remote Debug
# =============================================================================
# Usage:
#   start-backend.sh [project-dir] [profile]
#
# Examples:
#   start-backend.sh                    # /workspace/repo, profil: dev
#   start-backend.sh /workspace/myapp   # custom directory
#   start-backend.sh /workspace/repo prod  # profil: prod
# =============================================================================

# Load sdkman for Java/Gradle/Maven
if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

set -e

PROJECT_DIR="${1:-/workspace/repo}"
PROFILE="${2:-dev}"

# Debug settings
DEBUG_PORT=5005
DEBUG_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:${DEBUG_PORT}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=============================================="
echo "  START BACKEND - Spring Boot + Debug"
echo -e "==============================================${NC}"
echo ""
echo "Project:     $PROJECT_DIR"
echo "Profile:     $PROFILE"
echo "Debug Port:  $DEBUG_PORT"
echo ""

cd "$PROJECT_DIR"

# Detect build type
if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    echo -e "${GREEN}Using Gradle...${NC}"
    echo ""
    
    # Export JAVA_OPTS dla debug
    export JAVA_OPTS="$DEBUG_OPTS -Xmx2g"
    
    # Run with debug
    ./gradlew bootRun \
        --args="--spring.profiles.active=${PROFILE}" \
        -Dorg.gradle.jvmargs="-Xmx1g" \
        --console=plain
        
elif [ -f "pom.xml" ]; then
    echo -e "${GREEN}Using Maven...${NC}"
    echo ""
    
    mvn spring-boot:run \
        -Dspring-boot.run.profiles="${PROFILE}" \
        -Dspring-boot.run.jvmArguments="${DEBUG_OPTS} -Xmx2g"
        
else
    echo -e "${YELLOW}No Gradle or Maven build file found!${NC}"
    echo "Make sure you're in the correct directory."
    exit 1
fi
