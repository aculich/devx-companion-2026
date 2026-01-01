#!/usr/bin/env bash
# =============================================================================
# sentinel.sh - Installation Sentinel Sidecar
# =============================================================================
# Real-time monitoring and analysis of installation processes using LLM-powered
# observation. Watches installation logs and provides early warning system
# for issues, antipatterns, and learning opportunities.
#
# Usage:
#   ./sentinel/sentinel.sh --log install.log --output observations.md
#   ./sentinel/sentinel.sh --log install.log --mode alert
#   ./sentinel/sentinel.sh --help
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPANION_DIR="$(dirname "$SCRIPT_DIR")"

# Default options
LOG_FILE=""
OUTPUT_FILE=""
MODE="observe"  # observe, alert, pause
LLM_MODEL="gpt-4o"
CHECK_INTERVAL=5  # seconds
DISK_CHECK_INTERVAL=30  # seconds

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[SENTINEL]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SENTINEL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[SENTINEL]${NC} $1"
}

log_error() {
    echo -e "${RED}[SENTINEL]${NC} $1" >&2
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Monitor installation logs in real-time with LLM-powered analysis.

OPTIONS:
    --log FILE          Installation log file to watch (required)
    --output FILE       Output file for observations (default: sentinel-observations.md)
    --mode MODE         Sentinel mode: observe, alert, pause (default: observe)
    --model MODEL       LLM model to use (default: gpt-4o)
    --interval SECONDS  Check interval in seconds (default: 5)
    --help, -h          Show this help

MODES:
    observe  - Watch and note, no intervention (default)
    alert    - Write alerts to file, continue
    pause    - Create pause file if critical issues detected

EXAMPLES:
    # Basic observation mode
    ./sentinel/sentinel.sh --log install.log

    # Alert mode with custom output
    ./sentinel/sentinel.sh --log install.log --mode alert --output alerts.md

    # Use specific LLM model
    ./sentinel/sentinel.sh --log install.log --model claude-3-5-sonnet
EOF
}

# =============================================================================
# Check Dependencies
# =============================================================================

check_dependencies() {
    local missing=""
    
    if ! command -v llm &>/dev/null; then
        missing="${missing}llm "
    fi
    
    if ! command -v tail &>/dev/null; then
        missing="${missing}tail "
    fi
    
    if [ -n "$missing" ]; then
        log_error "Missing dependencies: $missing"
        log_info "Install llm: brew install llm"
        return 1
    fi
    
    return 0
}

# =============================================================================
# Disk Space Monitoring
# =============================================================================

check_disk_space() {
    local free_space_gb
    free_space_gb=$(df -g / | awk 'NR==2 {print $4}')
    
    if [ "$free_space_gb" -lt 5 ]; then
        log_warning "Critical: Less than 5GB free disk space"
        return 2  # Critical
    elif [ "$free_space_gb" -lt 10 ]; then
        log_warning "Warning: Less than 10GB free disk space"
        return 1  # Warning
    fi
    
    return 0
}

# =============================================================================
# Error Pattern Detection
# =============================================================================

detect_error_patterns() {
    local log_file="$1"
    local last_check_file="${log_file}.sentinel-last-check"
    local last_position=0
    
    # Get last check position
    if [ -f "$last_check_file" ]; then
        last_position=$(cat "$last_check_file" 2>/dev/null || echo "0")
    fi
    
    # Check for error patterns in new content
    local errors=0
    if [ -f "$log_file" ]; then
        tail -c +"$last_position" "$log_file" 2>/dev/null | grep -iE "(error|failed|warn|exception|timeout|connection refused|permission denied|not found|requires)" > /dev/null && errors=1 || true
    fi
    
    # Update last check position
    if [ -f "$log_file" ]; then
        wc -c < "$log_file" > "$last_check_file" 2>/dev/null || true
    fi
    
    return $errors
}

# =============================================================================
# LLM Analysis
# =============================================================================

analyze_with_llm() {
    local log_snippet="$1"
    local prompt_file="$SCRIPT_DIR/prompts/system-prompt.txt"
    
    # Use system prompt if available, otherwise inline
    local prompt
    if [ -f "$prompt_file" ]; then
        prompt=$(cat "$prompt_file")
    else
        prompt="You are an installation sentinel monitoring a macOS toolchain installation.
Watch for:
- Error patterns (Error:, Failed, WARN, exception)
- Slow operations (> 2 minutes without progress)
- Disk space concerns (< 5GB free)
- Network issues (timeout, connection refused)
- Permission problems (sudo, access denied)
- Dependency failures (requires, not found)

For each observation, note:
- Timestamp
- Severity (INFO, WARN, ERROR, CRITICAL)
- Pattern matched
- Suggested action
- Learning log candidate? (yes/no)

Analyze this log snippet:
$log_snippet"
    fi
    
    if llm -m "$LLM_MODEL" "$prompt" 2>/dev/null; then
        return 0
    else
        log_warning "LLM analysis failed (may need API key configured)"
        return 1
    fi
}

# =============================================================================
# Write Observation
# =============================================================================

write_observation() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local severity="$1"
    local category="$2"
    local message="$3"
    local suggestion="${4:-}"
    
    {
        echo ""
        echo "## Observation: $timestamp"
        echo ""
        echo "**Severity**: $severity"
        echo "**Category**: $category"
        echo "**Message**: $message"
        if [ -n "$suggestion" ]; then
            echo "**Suggestion**: $suggestion"
        fi
        echo ""
    } >> "$OUTPUT_FILE"
}

# =============================================================================
# Main Monitoring Loop
# =============================================================================

monitor_loop() {
    local log_file="$1"
    local last_size=0
    local disk_check_counter=0
    local critical_issues=0
    
    log_info "Starting sentinel monitoring..."
    log_info "Mode: $MODE"
    log_info "Log file: $log_file"
    log_info "Output file: $OUTPUT_FILE"
    echo ""
    
    # Initialize output file
    {
        echo "# Sentinel Observations"
        echo ""
        echo "**Started**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "**Mode**: $MODE"
        echo "**Log file**: $log_file"
        echo ""
        echo "---"
        echo ""
    } > "$OUTPUT_FILE"
    
    # Monitor loop
    while true; do
        # Check if log file exists and has grown
        if [ -f "$log_file" ]; then
            local current_size
            current_size=$(wc -c < "$log_file" 2>/dev/null || echo "0")
            
            if [ "$current_size" -gt "$last_size" ]; then
                # New content available
                local new_content
                new_content=$(tail -c +$((last_size + 1)) "$log_file" 2>/dev/null || echo "")
                
                if [ -n "$new_content" ]; then
                    # Detect error patterns
                    if detect_error_patterns "$log_file"; then
                        log_warning "Error patterns detected in log"
                        write_observation "WARN" "Error Pattern" "Error patterns detected in installation log" "Review log for specific errors"
                        
                        # Analyze with LLM (sample last 1000 chars)
                        local sample
                        sample=$(echo "$new_content" | tail -c 1000)
                        if analyze_with_llm "$sample" >> "$OUTPUT_FILE" 2>/dev/null; then
                            log_info "LLM analysis added to observations"
                        fi
                    fi
                fi
                
                last_size=$current_size
            fi
        else
            log_warning "Log file not found: $log_file"
            sleep "$CHECK_INTERVAL"
            continue
        fi
        
        # Periodic disk space check
        disk_check_counter=$((disk_check_counter + CHECK_INTERVAL))
        if [ $disk_check_counter -ge $DISK_CHECK_INTERVAL ]; then
            disk_check_counter=0
            if ! check_disk_space; then
                local disk_status=$?
                if [ $disk_status -eq 2 ]; then
                    write_observation "CRITICAL" "Disk Space" "Less than 5GB free disk space" "Free up disk space or abort installation"
                    critical_issues=$((critical_issues + 1))
                elif [ $disk_status -eq 1 ]; then
                    write_observation "WARN" "Disk Space" "Less than 10GB free disk space" "Monitor disk usage closely"
                fi
            fi
        fi
        
        # Check for pause file (if another process wants us to stop)
        if [ -f "${log_file}.sentinel-pause" ]; then
            log_info "Pause file detected, stopping sentinel"
            break
        fi
        
        # Handle critical issues based on mode
        if [ "$MODE" = "pause" ] && [ $critical_issues -gt 0 ]; then
            log_error "Critical issues detected, creating pause file"
            touch "${log_file}.sentinel-pause-required"
            break
        fi
        
        sleep "$CHECK_INTERVAL"
    done
    
    # Final summary
    {
        echo ""
        echo "---"
        echo ""
        echo "**Stopped**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "**Critical issues**: $critical_issues"
        echo ""
    } >> "$OUTPUT_FILE"
    
    log_info "Sentinel monitoring stopped"
    log_info "Observations written to: $OUTPUT_FILE"
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --log)
                LOG_FILE="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --mode)
                MODE="$2"
                shift 2
                ;;
            --model)
                LLM_MODEL="$2"
                shift 2
                ;;
            --interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$LOG_FILE" ]; then
        log_error "Required: --log FILE"
        usage
        exit 1
    fi
    
    # Set default output file
    if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="${LOG_FILE%.log}-sentinel-observations.md"
    fi
    
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    # Start monitoring
    monitor_loop "$LOG_FILE"
}

main "$@"

