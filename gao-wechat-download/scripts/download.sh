#!/bin/bash
# gao-wechat-download - Download WeChat articles with curl/CloakBrowser fallback
# Uses Python for reliable HTML extraction

set -e

URL="$1"
OUTPUT_DIR="${OUTPUT_DIR:-/root/wechat/raw}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CLOAKBROWSER_PATH="/root/.cloakbrowser/chromium-146.0.7680.177.3/chrome"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"

OUTPUT_DIR="${OUTPUT_DIR/#\~/$HOME}"
mkdir -p "${OUTPUT_DIR}"

log() { echo "[gao-wechat] $1"; }

# Validate URL
[[ "$URL" =~ mp\.weixin\.qq\.com ]] || { log "ERROR: Invalid WeChat URL"; exit 1; }

# Generate slug (use Python for Unicode support)
generate_slug() {
    local title="$1"
    local slug=$(python3 -c "
import re
title = '''$title'''
cleaned = re.sub(r'[^\w\u4e00-\u9fff\s-]', '', title).strip()
if not cleaned:
    print('')
else:
    cjk_count = len(re.findall(r'[\u4e00-\u9fff]', cleaned))
    if cjk_count > len(cleaned) * 0.3:
        slug = cleaned[:20].replace(' ', '-')
    else:
        slug = re.sub(r'\s+', '-', cleaned.lower())[:50]
    print(slug)
" 2>/dev/null)
    [[ -z "$slug" || "$slug" == "-" ]] && slug=$(date +"%Y%m%d-%H%M%S")
    echo "$slug"
}

timestamp() { date +"%Y%m%d-%H%M%S"; }

# ============================================
# MODE 1: Curl (using Python extraction)
# ============================================
try_curl() {
    log "Mode: curl"
    local tmp_html="${OUTPUT_DIR}/.curl_temp_${timestamp}.html"
    local tmp_json="${OUTPUT_DIR}/.curl_result_${timestamp}.json"
    
    # Fetch with proven headers
    curl -s -L \
        -A "$USER_AGENT" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        -H "Accept-Language: zh-CN,zh;q=0.9,en;q=0.8" \
        --connect-timeout 15 \
        --max-time 30 \
        -o "$tmp_html" \
        "$URL"
    
    # Extract using Python (reliable extraction)
    python3 "${SCRIPT_DIR}/extract.py" "$tmp_html" "$tmp_json" 2>/dev/null
    local exit_code=$?
    
    [[ ! -f "$tmp_json" ]] && { log "Curl: extraction failed"; rm -f "$tmp_html"; return 1; }
    
    # Parse JSON result
    local result=$(cat "$tmp_json")
    local title=$(python3 -c "import json,sys; print(json.load(sys.stdin)['title'])" <<< "$result")
    local author=$(python3 -c "import json,sys; print(json.load(sys.stdin)['author'])" <<< "$result")
    local content=$(python3 -c "import json,sys; print(json.load(sys.stdin)['content'])" <<< "$result")
    local content_len=$(python3 -c "import json,sys; print(json.load(sys.stdin)['content_len'])" <<< "$result")
    local blocked=$(python3 -c "import json,sys; print(json.load(sys.stdin)['is_blocked'])" <<< "$result")
    local images_json=$(python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin)['images']))" <<< "$result")
    
    rm -f "$tmp_html" "$tmp_json"
    
    # Check if blocked
    if [[ "$blocked" == "True" ]]; then
        log "Curl: blocked (title=$title, len=$content_len)"
        return 1
    fi
    
    log "Curl: SUCCESS (title=$title, author=$author, len=$content_len)"
    
    # Generate paths
    local slug=$(generate_slug "$title")
    local article_dir="${OUTPUT_DIR}/${slug}"
    local img_dir="${article_dir}/imgs"
    local output_file="${OUTPUT_DIR}/${slug}.md"
    
    # Download images
    mkdir -p "$img_dir"
    local img_count=0
    while IFS= read -r img_url; do
        [[ -z "$img_url" ]] && continue
        img_url="${img_url//&amp;/&}"
        img_count=$((img_count + 1))
        
        local ext="png"
        [[ "$img_url" =~ \.(jpg|jpeg|gif|webp)(\?|$) ]] && ext="${BASH_REMATCH[1]}"
        
        log "Image $img_count: downloading"
        curl -s -L -A "$USER_AGENT" -H "Referer: $URL" \
             -o "${img_dir}/img-$(printf '%03d' $img_count).${ext}" \
             "${img_url}" 2>/dev/null || true
    done <<< "$(python3 -c "import json; print('\n'.join(json.loads('''$images_json''' or '[]')))" 2>/dev/null)"
    
    log "Images: $img_count downloaded"
    
    # Create markdown
    local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local date_str=$(date +"%Y-%m-%d")
    
    cat > "$output_file" << EOF
---
title: "${title}"
author: "${author}"
date: "${date_str}"
source_url: "${URL}"
captured_at: "${ts}"
download_mode: "curl"
images: ${img_count}
---

# ${title}

${content}
EOF
    
    OUTPUT_FILE="$output_file"
    log "Saved: $output_file"
    return 0
}

# ============================================
# MODE 2: CloakBrowser (improved)
# ============================================
try_cloakbrowser() {
    log "Mode: CloakBrowser"
    
    [[ -x "$CLOAKBROWSER_PATH" ]] || { log "CloakBrowser: not installed"; return 1; }
    
    local tmp_json="${OUTPUT_DIR}/.cloak_${timestamp}.json"
    
    cd "${SCRIPT_DIR}"
    timeout 90 node cloakbrowser-fetch.mjs "$URL" "$tmp_json" 2>&1 || true
    
    [[ -f "$tmp_json" ]] || { log "CloakBrowser: no output"; return 1; }
    
    # Parse JSON result
    local result=$(cat "$tmp_json")
    local title=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('title',''))" <<< "$result" 2>/dev/null)
    local author=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('author',''))" <<< "$result" 2>/dev/null)
    local content=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('content',''))" <<< "$result" 2>/dev/null)
    local blocked=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('hasCaptcha',False))" <<< "$result" 2>/dev/null)
    local images=$(python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin).get('images',[])))" <<< "$result" 2>/dev/null)
    
    rm -f "$tmp_json"
    
    # Check result
    if [[ "$blocked" == "True" ]] || [[ ${#content} -lt 100 ]]; then
        log "CloakBrowser: blocked (title=$title, content_len=${#content})"
        return 1
    fi
    
    log "CloakBrowser: SUCCESS (title=$title, content_len=${#content})"
    
    # Generate paths
    local slug=$(generate_slug "$title")
    local article_dir="${OUTPUT_DIR}/${slug}"
    local img_dir="${article_dir}/imgs"
    local output_file="${OUTPUT_DIR}/${slug}.md"
    
    # Download images from CloakBrowser result
    mkdir -p "$img_dir"
    local img_count=0
    while IFS= read -r img_url; do
        [[ -z "$img_url" ]] && continue
        img_count=$((img_count + 1))
        local ext="png"
        [[ "$img_url" =~ \.(jpg|jpeg|gif|webp) ]] && ext="${BASH_REMATCH[1]}"
        curl -s -L -A "$USER_AGENT" -H "Referer: $URL" \
             -o "${img_dir}/img-$(printf '%03d' $img_count).${ext}" "$img_url" || true
    done <<< "$images"
    
    # Create markdown
    local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local date_str=$(date +"%Y-%m-%d")
    
    cat > "$output_file" << EOF
---
title: "${title}"
author: "${author}"
date: "${date_str}"
source_url: "${URL}"
captured_at: "${ts}"
download_mode: "cloakbrowser"
images: ${img_count}
---

# ${title}

${content}
EOF
    
    OUTPUT_FILE="$output_file"
    log "Saved: $output_file"
    return 0
}

# ============================================
# Self-Healing
# ============================================
self_heal() {
    log "Self-healing: recording failure"
    local log_file="${OUTPUT_DIR}/.wechat_failures.log"
    echo "{\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"url\":\"$URL\"}" >> "$log_file"
    
    local fails=$(wc -l < "$log_file" 2>/dev/null || echo 0)
    log "Failure count: $fails"
    
    if [[ $fails -ge 3 ]]; then
        log "Evolution triggered: updating User-Agent"
        local chrome_ver=$(shuf -i 120-146 -n 1)
        sed -i "s/USER_AGENT=.*/USER_AGENT=\"Mozilla\/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit\/537.36 (KHTML, like Gecko) Chrome\/${chrome_ver}.0.0.0 Safari\/537.36\"/" "${SCRIPT_DIR}/download.sh"
        log "User-Agent updated to Chrome/${chrome_ver}"
        rm -f "$log_file"
    fi
}

# ============================================
# Git Push - Auto-detect git repo in current or parent directories
# ============================================
git_push() {
    local title=$(grep '^title:' "$OUTPUT_FILE" 2>/dev/null | sed 's/title: "//;s/"$//' || echo "WeChat article")
    
    # Auto-detect git repo: check OUTPUT_DIR, then parent directories
    local repo_root=""
    
    # Check if OUTPUT_DIR itself is a git repo
    if git -C "$OUTPUT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
        repo_root=$(git -C "$OUTPUT_DIR" rev-parse --show-toplevel)
    fi
    
    # If not found, walk up parent directories
    if [[ -z "$repo_root" ]]; then
        local check_dir="$OUTPUT_DIR"
        while [[ "$check_dir" != "/" ]]; do
            if git -C "$check_dir" rev-parse --is-inside-work-tree &>/dev/null; then
                repo_root=$(git -C "$check_dir" rev-parse --show-toplevel)
                # Verify repo has remote
                if git -C "$repo_root" remote | grep -q .; then
                    break
                fi
            fi
            check_dir=$(dirname "$check_dir")
        done
    fi
    
    # Skip if no repo found
    if [[ -z "$repo_root" ]] || ! git -C "$repo_root" remote | grep -q .; then
        log "Git: no repo with remote found, skipping"
        return 0
    fi
    
    log "Git: detected repo at $repo_root"
    cd "$repo_root"
    
    # Add and commit
    git add . 2>/dev/null || true
    git commit -m "Add WeChat article: ${title}" 2>/dev/null || {
        log "Git: nothing to commit"
        return 0
    }
    
    # Push to remote
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    local remote=$(git remote | head -1)
    if git push "$remote" "$branch" 2>/dev/null; then
        log "Git: pushed to $remote/$branch"
    else
        log "Git: commit done, push failed (check auth/network)"
    fi
}

# ============================================
# Main Execution
# ============================================
OUTPUT_FILE=""
DOWNLOAD_MODE=""

# Try curl first
if try_curl; then
    DOWNLOAD_MODE="curl"
    git_push
    log "SUCCESS (curl)"
    echo "File: ${OUTPUT_FILE}"
    exit 0
fi

# Fallback to CloakBrowser
if try_cloakbrowser; then
    DOWNLOAD_MODE="cloakbrowser"
    git_push
    log "SUCCESS (cloakbrowser)"
    echo "File: ${OUTPUT_FILE}"
    exit 0
fi

# Both failed - self-healing
self_heal
log "FAILED: both modes blocked"
echo "Self-healing initiated. Check .wechat_failures.log"
exit 1