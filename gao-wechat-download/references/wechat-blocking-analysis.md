# WeChat Captcha Blocking Analysis

Session-tested findings on WeChat's automated access blocking.

## Comparison: crawl4ai vs CloakBrowser

Test date: 2026-05-12

| Tool | Result | Reason |
|------|--------|--------|
| crawl4ai | BLOCKED | Returns "环境异常" captcha page, 86 chars |
| CloakBrowser | SUCCESS | Bypasses captcha, gets full content (3693 chars) |
| curl (wechat-article-downloader) | SUCCESS | Simple HTTP requests don't trigger captcha |

### crawl4ai Output (Blocked)
```
Title: Weixin Official Accounts Platform
Content: "环境异常，当前环境异常，完成验证后即可继续访问"
Length: 86 chars
```

### CloakBrowser Output (Success)
```
Title: 我用 Tushare + Claude Code，手搓了一套本地股票数据同步系统
Content: Full article body
Length: 3693 chars
Images: 10
```

## Detection Patterns

### Captcha Indicators (Blocked)
- Title: "微信公众平台" or "Weixin Official Accounts Platform"
- HTML contains: "环境异常", "wappoc_appmsgcaptcha"
- Content length < 100 chars
- `#js_content` div empty or missing

### Success Indicators
- Title matches actual article title
- `#js_content` div has > 500 chars
- Images extracted from `data-src` attributes

## URLs That Are Problematic

### Successfully Downloaded
- `https://mp.weixin.qq.com/s/7e2PNvwVYReayRP21Ao4fw` - Works with CloakBrowser

### Blocked by Both curl and CloakBrowser
- `https://mp.weixin.qq.com/s/Z8CwvP_kQW5xa2-_zZP01A` - Returns "微信公众平台" title

**Note**: Some URLs may have additional anti-scraping measures beyond standard captcha. These require:
1. User to manually copy content
2. Or use `--wait` mode with manual login
3. Or wait for WeChat to relax restrictions on that specific URL

## Technical Fixes Applied

### Slug Generation (Unicode Support)
PCRE2 regex in bash doesn't support `\u4e00-\u9fff` Unicode ranges.

**Fix**: Use Python for slug generation:
```python
import re
cleaned = re.sub(r'[^\w\u4e00-\u9fff\s-]', '', title).strip()
if cjk_count > len(cleaned) * 0.3:
    slug = cleaned[:20].replace(' ', '-')
```

### CloakBrowser Timing
- `waitUntil: 'networkidle2'` can timeout on slow pages
- Fallback to `'domcontentloaded'` + 5s wait
- Additional 3s wait after `#js_content` found

## Self-Healing Mechanism

When 3+ consecutive failures recorded:
1. Rotate User-Agent to newer Chrome version (120-146)
2. Clear failure log
3. Retry download

Failure log format:
```json
{"time": "2026-05-12T03:10:00Z", "url": "https://mp.weixin.qq.com/s/xxx"}
```

## Recommendations

1. **Default to curl first** - fastest, works for most URLs
2. **Fallback to CloakBrowser** - handles captcha-evading cases
3. **Accept some URLs cannot be scraped** - user must provide content manually
4. **Don't hardcode "this tool doesn't work"** - blocking is URL-specific, not universal