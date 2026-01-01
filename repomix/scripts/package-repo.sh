#!/usr/bin/env bash
# =============================================================================
# package-repo.sh - Package Repository with Repomix
# =============================================================================
# Wrapper script for Repomix to package repositories with consistent settings.
#
# Usage:
#   ./repomix/scripts/package-repo.sh /path/to/repo
#   ./repomix/scripts/package-repo.sh --remote https://github.com/user/repo
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOMIX_DIR="$(dirname "$SCRIPT_DIR")"
COMPANION_DIR="$(dirname "$REPOMIX_DIR")"

CONFIG_FILE="${REPOMIX_DIR}/config.json"
OUTPUT_STYLE="xml"
COMPRESS=true
REMOTE=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [REPO_PATH]

Package a repository with Repomix for AI analysis.

OPTIONS:
    --config FILE       Repomix config file (default: repomix/config.json)
    --style STYLE       Output style: xml, markdown, json, plain (default: xml)
    --compress          Enable compression (default: true)
    --no-compress       Disable compression
    --remote URL        Package remote GitHub repository
    --help, -h          Show this help

EXAMPLES:
    # Package local repo
    ./repomix/scripts/package-repo.sh /path/to/repo

    # Package remote repo
    ./repomix/scripts/package-repo.sh --remote https://github.com/user/repo

    # Generate markdown output
    ./repomix/scripts/package-repo.sh --style markdown /path/to/repo
EOF
}

main() {
    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --style)
                OUTPUT_STYLE="$2"
                shift 2
                ;;
            --compress)
                COMPRESS=true
                shift
                ;;
            --no-compress)
                COMPRESS=false
                shift
                ;;
            --remote)
                REMOTE="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
            *)
                REPO_PATH="$1"
                shift
                ;;
        esac
    done
    
    # Check if repomix is available
    if ! command -v npx &>/dev/null; then
        echo "Error: npx not found. Install Node.js first." >&2
        exit 1
    fi
    
    # Build repomix command
    local cmd="npx repomix@latest"
    
    if [ -n "$REMOTE" ]; then
        cmd="$cmd --remote \"$REMOTE\""
    elif [ -n "${REPO_PATH:-}" ]; then
        cmd="$cmd \"$REPO_PATH\""
    else
        cmd="$cmd ."
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        cmd="$cmd --config \"$CONFIG_FILE\""
    fi
    
    if [ "$COMPRESS" = true ]; then
        cmd="$cmd --compress"
    fi
    
    cmd="$cmd --style \"$OUTPUT_STYLE\""
    
    echo "Running: $cmd"
    eval "$cmd"
}

main "$@"

