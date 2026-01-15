#!/bin/bash
# =============================================================================
# ENTRYPOINT SCRIPT - Initializing the sandbox environment
# =============================================================================

# Load sdkman and nvm for tool availability
if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

if [ -f "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
fi

set -e

echo "=============================================="
echo "  DEV SANDBOX - Starting..."
echo "=============================================="

# Make sure directories have the correct permissions
chown -R developer:developer /workspace 2>/dev/null || true
chown -R developer:developer /home/developer/.gradle 2>/dev/null || true
chown -R developer:developer /home/developer/.m2 2>/dev/null || true
chown -R developer:developer /home/developer/.npm 2>/dev/null || true
chown -R developer:developer /home/developer/.sdkman 2>/dev/null || true
chown -R developer:developer /home/developer/.nvm 2>/dev/null || true

# Create supervisor log directory
mkdir -p /var/log/supervisor
chmod 755 /var/log/supervisor

# Generate host SSH keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
fi

# Display environment information (run as developer user since tools are in their home)
echo ""
echo "Environment:"
echo "  Java:   $(su - developer -c 'source ~/.sdkman/bin/sdkman-init.sh && java -version' 2>&1 | head -1)"
echo "  Gradle: $(su - developer -c 'source ~/.sdkman/bin/sdkman-init.sh && gradle --version' 2>/dev/null | grep Gradle || echo 'N/A')"
echo "  Maven:  $(su - developer -c 'source ~/.sdkman/bin/sdkman-init.sh && mvn --version' 2>/dev/null | head -1 || echo 'N/A')"
echo "  Node:   $(su - developer -c 'source ~/.nvm/nvm.sh && node --version' 2>/dev/null || echo 'N/A')"
echo "  NPM:    $(su - developer -c 'source ~/.nvm/nvm.sh && npm --version' 2>/dev/null || echo 'N/A')"
echo "  Python: $(python --version)"
echo ""
echo "Ports:"
echo "  SSH:          22   (IntelliJ Gateway)"
echo "  Spring Boot:  8080"
echo "  Java Debug:   5005"
echo "  Angular:      4200"
echo "  Node Debug:   9229"
echo ""
echo "User: developer (password: sandbox)"
echo "Workspace: /workspace"
echo ""
echo "=============================================="
echo "  Ready! Connect via SSH on port 2222"
echo "=============================================="
echo ""

# Start the main process
exec "$@"
