# =============================================================================
# DEV SANDBOX - Isolated development environment
# =============================================================================
# Full isolation: Gradle/Maven/NPM run ONLY inside the container
# Supports: Spring Boot, Angular/Node, Python
# Debug: Java Remote Debug + Node Inspector
# IDE: IntelliJ Gateway (Remote Development)
# AI: Claude Code with full access to /workspace
# =============================================================================

FROM ubuntu:24.04

LABEL maintainer="developer"
LABEL description="Isolated development sandbox for untrusted code"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Warsaw

# =============================================================================
# BASE SYSTEM + SSH (for IntelliJ Gateway)
# =============================================================================
RUN apt-get update && apt-get install -y \
    # Basic Tools
    curl \
    wget \
    git \
    sudo \
    vim \
    nano \
    htop \
    tree \
    unzip \
    zip \
    jq \
    # SSH server (required for IntelliJ Gateway)
    openssh-server \
    # Network Tools (Debug)
    net-tools \
    iputils-ping \
    dnsutils \
    # Localisation
    locales \
    tzdata \
    # Build essentials (for native Node modules)
    build-essential \
    python3-dev \
    # Processes
    supervisor \
    # Sandbox
    socat \
    bubblewrap \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# Locale
RUN locale-gen en_US.UTF-8 pl_PL.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# =============================================================================
# USER SETUP (moved before tool installation)
# =============================================================================
ARG USERNAME=developer
ARG USER_UID=1100
ARG USER_GID=1100

# Create user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# SSH setup
RUN mkdir -p /home/$USERNAME/.ssh \
    && chmod 700 /home/$USERNAME/.ssh \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

# Workspace
RUN mkdir -p /workspace && chown -R $USERNAME:$USERNAME /workspace

# Gradle/Maven cache in container (not on host!)
RUN mkdir -p /home/$USERNAME/.gradle /home/$USERNAME/.m2 /home/$USERNAME/.npm \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME/.gradle /home/$USERNAME/.m2 /home/$USERNAME/.npm

# =============================================================================
# JAVA/GRADLE/MAVEN (via sdkman)
# =============================================================================
USER $USERNAME
WORKDIR /home/$USERNAME

# Install sdkman
RUN curl -s "https://get.sdkman.io" | bash \
    && bash -c "source $HOME/.sdkman/bin/sdkman-init.sh \
    && sdk install java 21.0.5-tem \
    && sdk install gradle 8.5 \
    && sdk install maven 3.9.6 \
    && sdk default java 21.0.5-tem \
    && sdk default gradle 8.5 \
    && sdk default maven 3.9.6"

# Configure environment for sdkman
RUN echo 'source $HOME/.sdkman/bin/sdkman-init.sh' >> /home/$USERNAME/.bashrc

# =============================================================================
# NODE.JS (via nvm) + Angular CLI
# =============================================================================

# Install nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && bash -c "source $HOME/.nvm/nvm.sh \
    && nvm install 20 \
    && nvm use 20 \
    && nvm alias default 20"

# Install global npm packages
RUN bash -c "source $HOME/.nvm/nvm.sh \
    && npm install -g \
        @angular/cli \
        typescript \
        ts-node \
        nodemon \
        npm-check-updates"

# Configure environment for nvm
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> /home/$USERNAME/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"' >> /home/$USERNAME/.bashrc

# =============================================================================
# PLAYWRIGHT SYSTEM DEPENDENCIES
# =============================================================================
RUN bash -c "source $HOME/.nvm/nvm.sh && npx -y playwright install-deps"

# Switch back to root for remaining setup
USER root

# =============================================================================
# PYTHON
# =============================================================================
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/bin/python

# Python packages (global)
RUN pip3 install --break-system-packages \
    virtualenv \
    pipenv \
    poetry \
    httpie \
    black \
    flake8

# =============================================================================
# CLAUDE CODE (via npm - install as developer user with nvm)
# =============================================================================
USER $USERNAME
RUN bash -c "source $HOME/.nvm/nvm.sh && npm install -g @anthropic-ai/claude-code"
USER root

# =============================================================================
# SSH SERVER CONFIG
# =============================================================================
RUN mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && echo "AllowUsers $USERNAME" >> /etc/ssh/sshd_config

# Set password for user (change in production or use SSH keys!)
RUN echo "$USERNAME:sandbox" | chpasswd

# =============================================================================
# SUPERVISOR (process management)
# =============================================================================
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# =============================================================================
# ENTRYPOINT SCRIPTS
# =============================================================================
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/clone-repo.sh /usr/local/bin/clone-repo.sh
COPY scripts/start-backend.sh /usr/local/bin/start-backend.sh
COPY scripts/start-frontend.sh /usr/local/bin/start-frontend.sh
COPY scripts/claude-worktree.sh /usr/local/bin/claude-worktree.sh
COPY agent/claude-job.sh /usr/local/bin/claude-job.sh
RUN chmod +x /usr/local/bin/*.sh

# =============================================================================
# CLAUDE JOB FOLDER
# =============================================================================
RUN mkdir -p /var/log/claude-jobs && chown -R $USERNAME:$USERNAME /var/log/claude-jobs

# =============================================================================
# PORTS
# =============================================================================
# SSH (IntelliJ Gateway)
EXPOSE 22
# Spring Boot
EXPOSE 8080
# Spring Boot Debug
EXPOSE 5005
# Angular Dev Server
EXPOSE 4200
# Node Debug
EXPOSE 9229
# Additional ports for other services
EXPOSE 3000 3001 5000 5001

# =============================================================================
# HEALTHCHECK
# =============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -x sshd > /dev/null || exit 1

# =============================================================================
# STARTUP
# =============================================================================
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
