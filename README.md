# DevX Companion

> Companion tools for deployment, monitoring, and analysis of development environments

## Purpose

This repository contains utility tools that support the deployment and monitoring of development toolchains. It serves as a "budding shoot" that grew from toolchain-2026 and has matured into its own focused space.

## Components

### Sentinel System
Real-time monitoring and analysis of installation processes using LLM-powered observation.

- **`sentinel/sentinel.sh`** - Main sentinel script that watches installation logs
- **`sentinel/prompts/`** - LLM system prompts for analysis
- **`sentinel/config.yaml`** - Sentinel configuration

### Screenshot Analysis
Systematic analysis of screenshots for lessons learned extraction.

- **`screenshot-analysis/analyze-screenshots.sh`** - Main analysis script
- **`screenshot-analysis/prompts/`** - LLM prompts for screenshot analysis

### Repomix Integration
Integration with [Repomix](https://repomix.com/) for AI-optimized codebase snapshots.

- **`repomix/config.json`** - Repomix configuration
- **`repomix/scripts/`** - Repomix automation scripts

### Deployment Orchestration
Scripts for multi-machine deployment and environment-specific configurations.

- **`deployment/`** - Deployment orchestration scripts

### Learning Synchronization
Scripts to sync local learnings to outer-world-context repository.

- **`sync/sync-learnings.sh`** - Sync local learnings to outer-world
- **`sync/promote-learnings.sh`** - Identify and promote learnings

## Dependencies

- `llm` CLI (from toolchain-2026 base layer)
- `tesseract` (OCR engine)
- `poppler` (PDF tools)
- `repomix` (npm package)

## Related Repositories

- **toolchain-2026** - Primary toolchain configuration (this repo's origin)
- **outer-world-context** - Global personal context and learnings

## Usage

### Sentinel

```bash
# Watch an installation log
./sentinel/sentinel.sh --log /path/to/install.log --output observations.md

# Enable in install.sh
./install.sh --base --ai --sentinel
```

### Screenshot Analysis

```bash
# Analyze screenshots in Desktop and Documents
./screenshot-analysis/analyze-screenshots.sh ~/Desktop ~/Documents

# OCR only (faster, no API calls)
./screenshot-analysis/analyze-screenshots.sh --ocr-only
```

### Learning Sync

```bash
# Sync learnings to outer-world-context
./sync/sync-learnings.sh
```

## Learning Logs

This repository maintains its own local learning logs in `learning/`:
- `LEARNING_LOG.md` - Companion-specific lessons
- `FEED_FORWARD_LOG.md` - Companion-specific feed-forward

Learnings are synced to `outer-world-context` when they meet promotion criteria (cross-project applicability, reusable patterns, fundamental insights).

## License

MIT

