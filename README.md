# Dev Sandbox - Isolated Development Environment

A secure, containerized development environment for working with untrusted code. Complete isolation from the host system with full development tooling support.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         macOS HOST                               │
│                                                                  │
│   ┌─────────────────┐        ┌─────────────────┐                 │
│   │ IntelliJ Gateway│        │    Browser      │                 │
│   │ (UI only)       │        │ localhost:4200  │                 │
│   └────────┬────────┘        │ localhost:8080  │                 │
│            │ SSH:2222        └────────┬────────┘                 │
├────────────┼──────────────────────────┼──────────────────────────┤
│            ▼                          ▼      DOCKER              │
│   ┌─────────────────────────────────────────────────────────┐    │
│   │              SANDBOX CONTAINER                          │    │
│   │                                                         │    │
│   │  /workspace/repo/          ← All code ONLY here         │    │
│   │  ├── src/main/java/...     (Spring Boot)                │    │
│   │  ├── build.gradle                                       │    │
│   │  └── ui/                   (Angular)                    │    │
│   │                                                         │    │
│   │  JDK 21 │ Node 20 │ Python │ Gradle │ Maven │ Claude    │    │
│   │                                                         │    │
│   │  :8080 Spring │ :4200 Angular │ :5005/:9229 Debug       │    │
│   └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│   ┌──────────────────────────┼──────────────────────────────┐    │
│   │              DATABASES   ▼  (optional)                  │    │
│   │      MySQL:3306 │ PostgreSQL:5432 │ Redis:6379          │    │
│   └─────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

**Key Features:**
- Gradle/Maven/NPM run ONLY inside the container
- No access to host filesystem
- IntelliJ works via SSH (Gateway)
- Native debug support
- Claude Code has full access to `/workspace`

## Quick Start

```bash
# Build and start
make build && make up

# Or with docker-compose directly
docker-compose up -d --build

# Connect via SSH
ssh -p 2222 developer@localhost
# Password: sandbox

# Clone a repository (inside container)
make clone URL=https://github.com/user/repo.git
```

## File Structure

```
dev-sandbox/
├── Dockerfile              # Container image definition
├── docker-compose.yml      # Service orchestration
├── Makefile                # Build automation & shortcuts
├── config/
│   └── supervisord.conf    # Process management configuration
├── scripts/
│   ├── entrypoint.sh       # Container initialization
│   ├── clone-repo.sh       # Repository cloning utility
│   ├── start-backend.sh    # Spring Boot launcher with debug
│   ├── start-frontend.sh   # Frontend launcher with debug
│   └── claude-worktree.sh  # Git worktree management for Claude
└── README.md               # This documentation
```

## File Descriptions

### Dockerfile
Builds an Ubuntu 24.04-based container with:
- **Development tools**: JDK 21, Gradle 8.5, Maven 3.9.6 (via SDKMAN)
- **Node.js 20** with Angular CLI, TypeScript (via NVM)
- **Python 3** with pip, virtualenv, poetry
- **Claude Code** CLI installed globally
- **SSH server** for IntelliJ Gateway remote development
- **Supervisor** for process management

### docker-compose.yml
Orchestrates the development environment:
- Main sandbox container with resource limits (4 CPU, 8GB RAM)
- Named volumes for workspace and build caches
- Port mappings for SSH, web apps, and debuggers
- Pre-configured database connections (MySQL, PostgreSQL, Redis - commented out by default)
- Optional network isolation for security

### Makefile
Provides convenient shortcuts:
- `make build` - Build Docker images
- `make up` - Start the environment
- `make down` - Stop containers
- `make shell` - Connect to sandbox as developer
- `make claude` - Run Claude Code in sandbox
- `make clone URL=...` - Clone a repository
- `make backend` - Start Spring Boot with debug
- `make frontend` - Start frontend with debug
- `make reset` - Complete reset (deletes all data)

### config/supervisord.conf
Manages container processes:
- Runs SSH daemon automatically at startup
- Optional configurations for Spring Boot and Angular (commented)

### scripts/entrypoint.sh
Container initialization script:
- Sets correct permissions on workspace and cache directories
- Generates SSH host keys
- Displays environment information (Java, Node, Python versions)
- Starts supervisor daemon

### scripts/clone-repo.sh
Safely clones repositories into the sandbox:
- Usage: `clone-repo.sh <git-url> [branch] [directory-name]`
- Shallow clone for faster downloads
- Auto-detects project type (Gradle, Maven, Node, Python)
- Provides next-step suggestions

### scripts/start-backend.sh
Launches Spring Boot applications with remote debugging:
- Usage: `start-backend.sh [project-dir] [profile]`
- Auto-detects Gradle or Maven
- Enables Java debug on port 5005
- Default profile: `dev`

### scripts/start-frontend.sh
Launches frontend development servers:
- Usage: `start-frontend.sh [project-dir] [port]`
- Auto-detects Angular, Next.js, Vite, or Create React App
- Enables Node.js debugging on port 9229
- Auto-runs `npm install` if needed

### scripts/claude-worktree.sh
Git worktree management for isolated Claude Code sessions:
- `create <feature>` - Create worktree and start Claude
- `commit <feature>` - Commit and optionally push changes
- `cleanup <feature>` - Remove worktree and branch
- `list` - Show active worktrees
- `status` - Show repository and worktree status

## Ports

| Port | Service |
|------|---------|
| 2222 | SSH (IntelliJ Gateway) |
| 8080 | Spring Boot |
| 5005 | Java Remote Debug |
| 4200 | Angular Dev Server |
| 9229 | Node.js Debug |
| 3306 | MySQL (optional) |
| 5432 | PostgreSQL (optional) |
| 6379 | Redis (optional) |

## IntelliJ Gateway Setup

1. Download [JetBrains Gateway](https://www.jetbrains.com/remote-development/gateway/)
2. Create SSH connection: `localhost:2222`, user: `developer`, password: `sandbox`
3. Select IntelliJ IDEA and project path: `/workspace/repo`

## Security

The sandbox provides isolation through:
- All build tools run inside the container only
- No access to host filesystem
- Named volumes for data persistence
- Optional network isolation (`internal: true` in docker-compose)
- Optional resource limits

## Troubleshooting

**SSH connection fails:**
```bash
docker-compose logs sandbox | grep ssh
docker exec -it dev-sandbox service ssh restart
```

**Port already in use:**
```bash
lsof -i :8080  # Check what's using the port
# Modify port mapping in docker-compose.yml
```

**Permission issues:**
```bash
docker exec -it dev-sandbox chown -R developer:developer /workspace
```

**Complete reset:**
```bash
make reset
# Or: docker-compose down -v && docker-compose up -d --build
```

## License

MIT