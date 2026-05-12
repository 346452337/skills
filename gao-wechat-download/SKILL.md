---
name: gao-wechat-download
description: Downloads WeChat Official Account (微信公众号) articles with intelligent curl/CloakBrowser fallback. Bypasses captcha, auto-heals on failure, saves to Markdown with images. Triggered by mp.weixin.qq.com URLs.
trigger: mp.weixin.qq.com
auto_approve: true
license: MIT
compatibility: Requires curl and CloakBrowser stealth Chromium
allowed-tools:
  - terminal
  - read_file
  - write_file
  - patch
  - search_files
metadata:
  author: gao
  version: "1.0.4"
---

# GAO WeChat Download Skill

Downloads WeChat articles with dual-mode fallback and self-evolution capabilities.

## Features

- **Dual-mode**: curl (primary) → CloakBrowser (fallback)
- **Captcha bypass**: Both modes designed to evade detection
- **Self-evolution**: Auto-heals on repeated failures
- **Markdown output**: YAML frontmatter + content + images
- **Git integration**: Auto-commit and push

## Configuration

| Setting | Value |
|---------|-------|
| Output dir | `~/wechat/raw` (configurable via OUTPUT_DIR env var) |
| Git repo | Auto-detected (walks up from OUTPUT_DIR to find nearest git repo with remote) |
| CloakBrowser | `/root/.cloakbrowser/chromium-146.0.7680.177.4/chrome` |

**Repo Structure** (example):
```
~/weichat/          # Main git repository (detected automatically)
├── raw/            # Downloaded articles (tracked in main repo)
│   ├── article-1.md
│   ├── article-1/imgs/*.png
│   └── ...
└── articles/       # Other content
```

**Git Detection**: The script automatically finds the git repo by walking up from OUTPUT_DIR's parent directories. Works with any repo location — not hardcoded to `~/weichat`.

## Workflow (Auto-triggered)

When user sends `mp.weixin.qq.com` URL:

```
1. Try curl mode (fast, lightweight)
   ├─ Success → Save, download images, git push
   └─ Blocked → Try CloakBrowser

2. Try CloakBrowser (stealth Chromium)
   ├─ Success → Save, download images, git push  
   └─ Blocked → Self-heal

3. Self-healing mode
   ├─ Record failure to log
   ├─ Analyze patterns (3+ failures triggers evolution)
   ├─ Apply fixes: new User-Agent, headers, timing
   └─ Optionally retry
```

## Agent Execution Instructions

```bash
SKILL_DIR="/root/.hermes/skills/gao-wechat-download"
URL="https://mp.weixin.qq.com/s/xxxxx"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/weichat/raw}"

# Run download script
${SKILL_DIR}/scripts/download.sh "${URL}" "${OUTPUT_DIR}"
```

The script will:
1. Attempt curl mode first
2. Fall back to CloakBrowser if blocked
3. Self-heal if both fail
4. Git push on success

## Output Format

```markdown
---
title: "文章标题"
author: "公众号名"
date: "2026-05-12"
source_url: "https://mp.weixin.qq.com/s/xxxx"
captured_at: "2026-05-12T10:30:00Z"
download_mode: "curl|cloakbrowser"
---

# 文章标题

文章内容...

![](imgs/img-001.png)
```

Files saved to:
- `{title-slug}.md` - Main article
- `{title-slug}/imgs/*.png` - Downloaded images

## Detection Logic

### Success Indicators
- HTTP 200 status
- Title matches article (not "Weixin Official Accounts Platform")
- `#js_content` div has substantial text (>200 chars)

### Failure Indicators
- HTML contains "环境异常" or "wappoc_appmsgcaptcha"
- Title is "Weixin Official Accounts Platform"
- Content length < 200 chars

## Self-Evolution

When both modes fail repeatedly:

1. **Record failure** to `.wechat_failures.log`
2. **Analyze patterns** after 3+ failures
3. **Apply fixes**:
   - Rotate User-Agent to new Chrome version
   - Add/modify request headers
   - Adjust CloakBrowser timing
4. **Update skill** via patch mechanism
5. **Clear log** and retry

Evolution log: `.skill_evolution.log`

## References

- `references/wechat-blocking-analysis.md` - Captcha detection patterns, crawl4ai vs CloakBrowser comparison, problematic URLs

## Pitfalls

### WeChat Captcha Detection
WeChat triggers captcha based on:
- Headless browser fingerprint
- Request frequency patterns
- User-Agent inconsistency

**Mitigations in this skill**:
- curl: Simple HTTP request (low detection)
- CloakBrowser: Pre-evaded stealth Chromium

### CloakBrowser Timeout
CloakBrowser may timeout on slow pages. Default: 90s.
Adjust via `WECHAT_TIMEOUT` env var.

### Some URLs Are Blocked by Both Modes
Certain URLs return "微信公众平台" title regardless of method used.
These have additional anti-scraping measures beyond standard captcha.
**Workaround**: User manually copies content, or use `--wait` mode with manual login.

### Image CDN Blocking
WeChat images on CDN may block scraping.
**Mitigation**: Use same User-Agent + Referer header.

### Unicode Slug Generation
PCRE2 regex in bash doesn't support `\u4e00-\u9fff` Unicode ranges.
**Fix**: This skill uses Python for slug generation.

### Nested .git Directory Causes Submodule Behavior
If the `raw` directory contains its own `.git` subdirectory, git will treat it as a submodule (mode 160000) instead of a regular directory when added to the parent repo.

**Symptoms**: `git add raw/` shows "adding embedded git repository" warning, files don't get tracked.

**Fix**:
```bash
git rm --cached raw          # Remove submodule entry from index
rm -rf raw/.git              # Delete nested git repo
git add raw/                 # Add properly as regular directory
git commit -m "Add raw directory"
git push
```

**Prevention**: Never run `git init` inside the output directory. The script detects the parent repo automatically and pushes from there.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `OUTPUT_DIR` | Custom output directory |
| `WECHAT_TIMEOUT` | CloakBrowser timeout (ms) |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Curl blocked | Falls back to CloakBrowser |
| CloakBrowser blocked | Self-heal runs, retries |
| Both blocked | Skill evolves, update UA |
| Git push fails | Check remote permissions |
| Images missing | Verify Referer header |
| raw shows as submodule | `rm -rf raw/.git && git add raw/` |

## Scripts

| Script | Purpose |
|--------|---------|
| `download.sh` | Main download script |
| `cloakbrowser-fetch.mjs` | CloakBrowser fetcher |
| `self-heal.sh` | Failure analysis & fix |

## References

- `references/wechat-download-research.md` - Tool comparison: curl vs CloakBrowser vs crawl4ai

## Related Skills

- `wechat-article-downloader` - Similar functionality using Bun/TypeScript; this skill uses Python for extraction

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-12 | Initial: curl/CloakBrowser dual-mode + self-heal |
| 1.0.1 | 2026-05-12 | Added Python extraction (more reliable than bash regex) |
| 1.0.2 | 2026-05-12 | Auto-detect git repo in current/parent directory |
| 1.0.3 | 2026-05-12 | Document nested .git pitfall, update troubleshooting |
| 1.0.4 | 2026-05-12 | Flexible git repo detection: walks up from OUTPUT_DIR to find any repo with remote (not hardcoded to ~/weichat) |