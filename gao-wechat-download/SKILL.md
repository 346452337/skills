---
name: gao-wechat-download
description: Downloads WeChat Official Account (微信公众号) articles with intelligent curl/CloakBrowser fallback. Bypasses captcha, auto-heals on failure, saves to Markdown with images. Triggered by mp.weixin.qq.com URLs. Use when user sends WeChat article links.
trigger: mp.weixin.qq.com
auto_approve: true
license: MIT
allowed-tools:
  - Bash(/root/.claude/skills/gao-wechat-download/scripts/download.sh *)
---

# GAO WeChat Download Skill

Downloads WeChat articles with dual-mode fallback and self-evolution capabilities.

## Multi-Agent Compatibility

This skill is compatible with:

| Agent | Integration Method |
|-------|-------------------|
| Claude Code | SKILL.md + scripts/ (auto-trigger via URL) |
| Cursor | Manual: call scripts/download.sh |
| Gemini/Copilot | Manual: call scripts/download.sh |
| Custom Agent | Use bash script directly |

## Quick Start

When user sends a WeChat URL like `https://mp.weixin.qq.com/s/xxxxx`:

```bash
# Auto-triggered in Claude Code, or run manually:
/root/.claude/skills/gao-wechat-download/scripts/download.sh "https://mp.weixin.qq.com/s/xxxxx" ~/wechat/raw
```

## Features

- **Dual-mode**: curl (primary) → CloakBrowser (fallback)
- **Captcha bypass**: Both modes designed to evade detection
- **Self-evolution**: Auto-heals on repeated failures
- **Markdown output**: YAML frontmatter + content + images
- **Git integration**: Auto-commit and push

## Output

```markdown
---
title: "文章标题"
author: "公众号名"
date: "2026-05-19"
source_url: "https://mp.weixin.qq.com/s/xxxx"
download_mode: "curl|cloakbrowser"
---

# 文章标题

文章内容...

![](imgs/img-001.png)
```

## Configuration

| Setting | Value |
|---------|-------|
| Output dir | `~/wechat/raw` (configurable via OUTPUT_DIR env) |
| CloakBrowser | `/root/.cloakbrowser/chromium-146.0.7680.177.3/chrome` |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `OUTPUT_DIR` | Custom output directory |
| `WECHAT_TIMEOUT` | CloakBrowser timeout (ms), default 90000 |

## Workflow

```
URL received → curl mode → SUCCESS → Save + Git push
                    ↓ BLOCKED
             CloakBrowser → SUCCESS → Save + Git push
                    ↓ BLOCKED
               Self-heal → Update UA → Retry
```

## Files

- `scripts/download.sh` - Main download script
- `scripts/cloakbrowser-fetch.mjs` - CloakBrowser fetcher
- `scripts/extract.py` - Python content extractor
- `scripts/self-heal.sh` - Failure analysis & fix

## Installation

```bash
# Ensure dependencies
which curl python3 node

# CloakBrowser (optional, for fallback)
pip install cloakbrowser
python -m cloakbrowser install

# Git repo setup
git clone https://github.com/YOUR_USERNAME/wechat.git ~/wechat
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Curl blocked | Falls back to CloakBrowser |
| CloakBrowser blocked | Self-heal runs |
| Git push fails | Check remote permissions |
| Images missing | Verify Referer header |

## Version

- 1.0.5 - Multi-agent compatibility (Claude Code, Cursor, Gemini, Custom)
- 1.0.4 - Flexible git repo detection
- 1.0.3 - Nested .git pitfall documented
- 1.0.2 - Auto-detect git repo
- 1.0.1 - Python extraction
- 1.0.0 - Initial release