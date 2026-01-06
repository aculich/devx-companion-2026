#!/usr/bin/env bash
# =============================================================================
# sentinel-v2.sh - Enhanced Installation Sentinel Sidecar
# =============================================================================
# Real-time monitoring with improved debouncing, LLM optimization, and
# local LLM support via Ollama.
#
# Usage:
#   ./sentinel/sentinel-v2.sh --log install.log --output observations.md
#   ./sentinel/sentinel-v2.sh --log install.log --llm-backend ollama
#   ./sentinel/sentinel-v2.sh --log install.log --llm-backend both --compare
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPANION_DIR="$(dirname "$SCRIPT_DIR")"
STATE_DIR="${TMPDIR:-/tmp}/sentinel-state"
mkdir -p "$STATE_DIR"

# Default options
LOG_FILE=""
OUTPUT_FILE=""
MODE="observe"
LLM_BACKEND="cloud"  # cloud, ollama, both
LLM_MODEL="gpt-4o"
OLLAMA_MODEL="llama3"
CHECK_INTERVAL=5
DISK_CHECK_INTERVAL=30
CONTEXT=""
SCREENSHOT_DIR=""
QUIET_MODE=false
DEBOUNCE_WINDOW=30  # seconds
LLM_BATCH_WINDOW=60  # seconds
SEVERITY_THRESHOLD="WARN"  # Only analyze WARN and above

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() {
    [ "$QUIET_MODE" = false ] && echo -e "${BLUE}[SENTINEL]${NC} $1"
}

log_success() {
    [ "$QUIET_MODE" = false ] && echo -e "${GREEN}[SENTINEL]${NC} $1"
}

log_warning() {
    [ "$QUIET_MODE" = false ] && echo -e "${YELLOW}[SENTINEL]${NC} $1"
}

log_error() {
    echo -e "${RED}[SENTINEL]${NC} $1" >&2
}

# Hash function for error patterns (simple MD5 if available, otherwise checksum)
hash_error() {
    local content="$1"
    if command -v md5 >/dev/null 2>&1; then
        echo "$content" | md5 | cut -d' ' -f4
    elif command -v md5sum >/dev/null 2>&1; then
        echo "$content" | md5sum | cut -d' ' -f1
    else
        # Fallback: use first 16 chars of content hash
        echo "$content" | shasum -a 256 | cut -c1-16
    fi
}

# Check if error was recently reported (debouncing)
is_error_recently_reported() {
    local error_hash="$1"
    local error_state_file="$STATE_DIR/error-${error_hash}.state"
    
    if [ ! -f "$error_state_file" ]; then
        return 1  # Not reported recently
    fi
    
    local last_reported=$(cat "$error_state_file" 2>/dev/null || echo "0")
    local now=$(date +%s)
    local age=$((now - last_reported))
    
    if [ $age -lt $DEBOUNCE_WINDOW ]; then
        return 0  # Recently reported
    else
        return 1  # Old enough to report again
    fi
}

# Mark error as reported
mark_error_reported() {
    local error_hash="$1"
    local error_state_file="$STATE_DIR/error-${error_hash}.state"
    echo "$(date +%s)" > "$error_state_file"
}

# Check if error was already analyzed by LLM
is_error_analyzed() {
    local error_hash="$1"
    local analysis_cache="$STATE_DIR/analysis-${error_hash}.cache"
    [ -f "$analysis_cache" ] && return 0 || return 1
}

# Cache LLM analysis result
cache_llm_analysis() {
    local error_hash="$1"
    local analysis="$2"
    local analysis_cache="$STATE_DIR/analysis-${error_hash}.cache"
    echo "$analysis" > "$analysis_cache"
}

# Get cached LLM analysis
get_cached_llm_analysis() {
    local error_hash="$1"
    local analysis_cache="$STATE_DIR/analysis-${error_hash}.cache"
    [ -f "$analysis_cache" ] && cat "$analysis_cache" || echo ""
}

# Check Ollama availability
check_ollama() {
    if command -v ollama >/dev/null 2>&1; then
        if ollama list >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Analyze with cloud LLM
analyze_with_cloud_llm() {
    local log_snippet="$1"
    local prompt_file="$SCRIPT_DIR/prompts/system-prompt.txt"
    
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
        return 1
    fi
}

# Analyze with Ollama
analyze_with_ollama() {
    local log_snippet="$1"
    local prompt_file="$SCRIPT_DIR/prompts/system-prompt.txt"
    
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
    
    if ollama run "$OLLAMA_MODEL" "$prompt" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Analyze with LLM (with caching and deduplication)
analyze_with_llm() {
    local log_snippet="$1"
    local error_hash=$(hash_error "$log_snippet")
    
    # Check cache first
    local cached=$(get_cached_llm_analysis "$error_hash")
    if [ -n "$cached" ]; then
        echo "$cached"
        return 0
    fi
    
    # Determine which backend(s) to use
    local analysis=""
    local cloud_analysis=""
    local ollama_analysis=""
    
    if [ "$LLM_BACKEND" = "cloud" ] || [ "$LLM_BACKEND" = "both" ]; then
        if analyze_with_cloud_llm "$log_snippet" > /tmp/sentinel-cloud-analysis.$$ 2>/dev/null; then
            cloud_analysis=$(cat /tmp/sentinel-cloud-analysis.$$)
            analysis="$cloud_analysis"
        fi
        rm -f /tmp/sentinel-cloud-analysis.$$
    fi
    
    if [ "$LLM_BACKEND" = "ollama" ] || [ "$LLM_BACKEND" = "both" ]; then
        if check_ollama; then
            if analyze_with_ollama "$log_snippet" > /tmp/sentinel-ollama-analysis.$$ 2>/dev/null; then
                ollama_analysis=$(cat /tmp/sentinel-ollama-analysis.$$)
                if [ "$LLM_BACKEND" = "both" ]; then
                    analysis="${analysis}\n\n---\n\n**Ollama Analysis:**\n${ollama_analysis}"
                else
                    analysis="$ollama_analysis"
                fi
            fi
            rm -f /tmp/sentinel-ollama-analysis.$$
        else
            log_warning "Ollama not available, falling back to cloud"
            if [ -z "$analysis" ]; then
                analyze_with_cloud_llm "$log_snippet" && analysis="$cloud_analysis" || true
            fi
        fi
    fi
    
    # Cache the analysis
    if [ -n "$analysis" ]; then
        cache_llm_analysis "$error_hash" "$analysis"
        echo "$analysis"
        return 0
    else
        return 1
    fi
}

# Detect error patterns with improved tracking
detect_error_patterns() {
    local log_file="$1"
    local last_check_file="${log_file}.sentinel-last-check"
    local last_position=0
    
    if [ -f "$last_check_file" ]; then
        last_position=$(cat "$last_check_file" 2>/dev/null || echo "0")
    fi
    
    local errors=0
    local error_content=""
    
    if [ -f "$log_file" ]; then
        local error_pattern="(error|failed|warn|exception|timeout|connection refused|permission denied|not found|requires)"
        
        if [ "$CONTEXT" = "bootstrap" ]; then
            error_pattern="${error_pattern}|(password|1password|touch.*id|sudo.*password|authentication|clone.*failed)"
        fi
        
        error_content=$(tail -c +"$last_position" "$log_file" 2>/dev/null | grep -iE "$error_pattern" | head -5 || echo "")
        
        if [ -n "$error_content" ]; then
            errors=1
        fi
    fi
    
    if [ -f "$log_file" ]; then
        wc -c < "$log_file" > "$last_check_file" 2>/dev/null || true
    fi
    
    # Return error content for hashing
    echo "$error_content"
    return $errors
}

# Write observation
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

# Main monitoring loop (enhanced)
monitor_loop() {
    local log_file="$1"
    local last_size=0
    local disk_check_counter=0
    local critical_issues=0
    local error_batch=""  # Batch errors for LLM analysis
    local batch_start_time=0
    
    log_info "Starting enhanced sentinel monitoring..."
    log_info "Mode: $MODE"
    log_info "LLM Backend: $LLM_BACKEND"
    if [ "$LLM_BACKEND" = "ollama" ] || [ "$LLM_BACKEND" = "both" ]; then
        if check_ollama; then
            log_success "Ollama available (model: $OLLAMA_MODEL)"
        else
            log_warning "Ollama not available"
        fi
    fi
    log_info "Log file: $log_file"
    log_info "Output file: $OUTPUT_FILE"
    [ "$QUIET_MODE" = true ] && log_info "Quiet mode enabled"
    echo ""
    
    # Initialize output file
    {
        echo "# Sentinel Observations (Enhanced)"
        echo ""
        echo "**Started**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "**Mode**: $MODE"
        echo "**LLM Backend**: $LLM_BACKEND"
        echo "**Context**: ${CONTEXT:-general}"
        echo "**Log file**: $log_file"
        if [ -n "$SCREENSHOT_DIR" ]; then
            echo "**Screenshot directory**: $SCREENSHOT_DIR"
        fi
        echo ""
        echo "---"
        echo ""
    } > "$OUTPUT_FILE"
    
    # Monitor loop
    while true; do
        if [ -f "$log_file" ]; then
            local current_size
            current_size=$(wc -c < "$log_file" 2>/dev/null || echo "0")
            
            if [ "$current_size" -gt "$last_size" ]; then
                local new_content
                new_content=$(tail -c +$((last_size + 1)) "$log_file" 2>/dev/null || echo "")
                
                if [ -n "$new_content" ]; then
                    # Detect error patterns
                    local error_content
                    error_content=$(detect_error_patterns "$log_file")
                    local has_errors=$?
                    
                    if [ $has_errors -eq 0 ] && [ -n "$error_content" ]; then
                        # Hash the error for deduplication
                        local error_hash=$(hash_error "$error_content")
                        
                        # Check if we should report this error (debouncing)
                        if ! is_error_recently_reported "$error_hash"; then
                            # Only log once per debounce window
                            log_warning "⚠️  Error patterns detected in log"
                            mark_error_reported "$error_hash"
                            
                            # Context-specific handling
                            if [ "$CONTEXT" = "bootstrap" ]; then
                                if echo "$new_content" | grep -qiE "password|sudo.*password"; then
                                    if [ "$QUIET_MODE" = false ]; then
                                        log_info "🎙️  Password prompt detected"
                                    fi
                                    write_observation "INFO" "User Interaction" "Password prompt detected" "User needs to provide password or use Touch ID"
                                fi
                                if echo "$new_content" | grep -qiE "1password|op.*account"; then
                                    if [ "$QUIET_MODE" = false ]; then
                                        log_info "🎙️  1Password setup in progress"
                                    fi
                                    write_observation "INFO" "1Password" "1Password CLI setup detected" "Monitoring for successful authentication"
                                fi
                                if echo "$new_content" | grep -qiE "touch.*id|pam_tid"; then
                                    if [ "$QUIET_MODE" = false ]; then
                                        log_info "🎙️  Touch ID setup detected"
                                    fi
                                    write_observation "INFO" "Touch ID" "Touch ID setup detected" "Monitoring for successful configuration"
                                fi
                            fi
                            
                            write_observation "WARN" "Error Pattern" "Error patterns detected in installation log" "Review log for specific errors"
                            
                            # Batch errors for LLM analysis (only analyze if not cached)
                            if ! is_error_analyzed "$error_hash"; then
                                if [ -z "$error_batch" ]; then
                                    batch_start_time=$(date +%s)
                                    error_batch="$error_content"
                                else
                                    error_batch="${error_batch}\n\n---\n\n${error_content}"
                                fi
                                
                                # Analyze batch if window expired or batch is large enough
                                local batch_age=$(($(date +%s) - batch_start_time))
                                if [ $batch_age -ge $LLM_BATCH_WINDOW ] || [ $(echo "$error_batch" | wc -l) -ge 5 ]; then
                                    local sample=$(echo "$error_batch" | tail -c 2000)
                                    if analyze_with_llm "$sample" >> "$OUTPUT_FILE" 2>/dev/null; then
                                        if [ "$QUIET_MODE" = false ]; then
                                            log_info "LLM analysis added to observations"
                                        fi
                                    fi
                                    error_batch=""
                                    batch_start_time=0
                                fi
                            else
                                # Use cached analysis
                                local cached_analysis=$(get_cached_llm_analysis "$error_hash")
                                if [ -n "$cached_analysis" ]; then
                                    echo "$cached_analysis" >> "$OUTPUT_FILE"
                                    if [ "$QUIET_MODE" = false ]; then
                                        log_info "Using cached LLM analysis"
                                    fi
                                fi
                            fi
                        fi
                    else
                        # Positive progress (only log in non-quiet mode)
                        if [ "$QUIET_MODE" = false ] && [ "$CONTEXT" = "bootstrap" ]; then
                            if echo "$new_content" | grep -qiE "success|completed|installed|configured"; then
                                log_info "🎙️  Progress: Installation step completed"
                            fi
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
        
        # Check for pause file
        if [ -f "${log_file}.sentinel-pause" ]; then
            log_info "Pause file detected, stopping sentinel"
            break
        fi
        
        # Handle critical issues
        if [ "$MODE" = "pause" ] && [ $critical_issues -gt 0 ]; then
            log_error "Critical issues detected, creating pause file"
            touch "${log_file}.sentinel-pause-required"
            break
        fi
        
        sleep "$CHECK_INTERVAL"
    done
    
    # Process any remaining batched errors
    if [ -n "$error_batch" ]; then
        local sample=$(echo "$error_batch" | tail -c 2000)
        if analyze_with_llm "$sample" >> "$OUTPUT_FILE" 2>/dev/null; then
            log_info "Final LLM analysis added to observations"
        fi
    fi
    
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
    
    # Cleanup state files older than 1 hour
    find "$STATE_DIR" -type f -mmin +60 -delete 2>/dev/null || true
}

# Check dependencies
check_dependencies() {
    local missing=""
    
    if [ "$LLM_BACKEND" = "cloud" ] || [ "$LLM_BACKEND" = "both" ]; then
        if ! command -v llm >/dev/null 2>&1; then
            missing="${missing}llm "
        fi
    fi
    
    if [ "$LLM_BACKEND" = "ollama" ] || [ "$LLM_BACKEND" = "both" ]; then
        if ! check_ollama; then
            if [ "$LLM_BACKEND" = "ollama" ]; then
                missing="${missing}ollama "
            else
                log_warning "Ollama not available, will use cloud only"
            fi
        fi
    fi
    
    if ! command -v tail >/dev/null 2>&1; then
        missing="${missing}tail "
    fi
    
    if [ -n "$missing" ]; then
        log_error "Missing dependencies: $missing"
        return 1
    fi
    
    return 0
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Enhanced installation sentinel with debouncing, LLM optimization, and local LLM support.

OPTIONS:
    --log FILE              Installation log file to watch (required)
    --output FILE           Output file for observations
    --mode MODE             Sentinel mode: observe, alert, pause (default: observe)
    --llm-backend BACKEND   LLM backend: cloud, ollama, both (default: cloud)
    --llm-model MODEL       Cloud LLM model (default: gpt-4o)
    --ollama-model MODEL    Ollama model (default: llama3)
    --interval SECONDS      Check interval in seconds (default: 5)
    --context CONTEXT       Context: bootstrap, install, etc.
    --screenshot-dir DIR    Directory for screenshots
    --quiet                 Quiet mode (minimal output)
    --debounce SECONDS      Debounce window in seconds (default: 30)
    --help, -h              Show this help

EXAMPLES:
    # Use Ollama only
    ./sentinel/sentinel-v2.sh --log install.log --llm-backend ollama

    # Compare both LLMs
    ./sentinel/sentinel-v2.sh --log install.log --llm-backend both --ollama-model llama3

    # Quiet mode
    ./sentinel/sentinel-v2.sh --log install.log --quiet
EOF
}

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
            --llm-backend)
                LLM_BACKEND="$2"
                shift 2
                ;;
            --llm-model)
                LLM_MODEL="$2"
                shift 2
                ;;
            --ollama-model)
                OLLAMA_MODEL="$2"
                shift 2
                ;;
            --interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            --context)
                CONTEXT="$2"
                shift 2
                ;;
            --screenshot-dir)
                SCREENSHOT_DIR="$2"
                shift 2
                ;;
            --quiet)
                QUIET_MODE=true
                shift
                ;;
            --debounce)
                DEBOUNCE_WINDOW="$2"
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

