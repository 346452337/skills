#!/bin/bash
# Self-healing script for gao-wechat-download skill
# Analyzes failures and attempts to fix

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
SKILL_MD="${SKILL_DIR}/SKILL.md"

log() { echo "[self-heal] $1"; }

analyze_failures() {
    local log_file="${OUTPUT_DIR}/.wechat_failures.log"
    
    if [[ ! -f "$log_file" ]]; then
        log "No failure log found"
        return 0
    fi
    
    local count=$(wc -l < "$log_file")
    log "Failure count: $count"
    
    if [[ $count -lt 3 ]]; then
        log "Not enough failures to trigger evolution"
        return 0
    fi
    
    log "Analyzing failure patterns..."
    
    # Determine what needs fixing
    local patterns=""
    
    # Check if curl consistently fails
    local curl_fails=$(grep -c "curl" "$log_file" 2>/dev/null || echo 0)
    local cloak_fails=$(grep -c "cloakbrowser" "$log_file" 2>/dev/null || echo 0)
    
    log "Curl failures: $curl_fails, CloakBrowser failures: $cloak_fails"
    
    # Generate fix suggestions
    if [[ $curl_fails -gt 0 ]]; then
        patterns+="curl_blocked: Need new User-Agent or headers\n"
    fi
    
    if [[ $cloak_fails -gt 0 ]]; then
        patterns+="cloak_blocked: Need timing adjustments or new evasion\n"
    fi
    
    log "Fix suggestions:\n$patterns"
    
    return 1
}

apply_fixes() {
    log "Applying fixes..."
    
    # Update User-Agent in download.sh (randomize)
    local new_ua="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$(shuf -i 120-146 -n 1).0.0.0 Safari/537.36"
    
    if grep -q "USER_AGENT=" "${SCRIPT_DIR}/download.sh"; then
        sed -i "s/^USER_AGENT=.*/USER_AGENT=\"$new_ua\"/" "${SCRIPT_DIR}/download.sh"
        log "Updated User-Agent"
    fi
    
    # Clear failure log
    rm -f "${OUTPUT_DIR}/.wechat_failures.log"
    
    log "Fixes applied, retrying download..."
}

retry_download() {
    local url="$1"
    local output_dir="$2"
    
    log "Retrying: $url"
    "${SCRIPT_DIR}/download.sh" "$url" "$output_dir"
}

# Main
URL="$1"
OUTPUT_DIR="${2:-$HOME/weichat/raw}"
OUTPUT_DIR="${OUTPUT_DIR/#\~/$HOME}"

if analyze_failures; then
    log "No evolution needed"
    exit 0
fi

apply_fixes

if [[ -n "$URL" ]]; then
    retry_download "$URL" "$OUTPUT_DIR"
fi

log "Self-healing complete"
exit 0