# Changelog

All notable changes to this project will be documented in this file.

## 2026-01-23

### Changed
- Enhanced Claude job script with worktrees support and significant improvements to `agent/claude-job.sh`

## 2026-01-22

### Added
- Claude job starting script (`agent/claude-job.sh`)
- Additional configuration in Dockerfile to support Claude job execution

## 2026-01-21

### Changed
- Updated Dockerfile with tmux support and minor fixes
- Improved docker-compose.yml configuration

## 2026-01-17

### Added
- Playwright system dependencies installation in Dockerfile
- `sudo` package to system dependencies in Dockerfile

### Changed
- Updated Dockerfile to include Playwright browser dependencies via `npx playwright install-deps`
