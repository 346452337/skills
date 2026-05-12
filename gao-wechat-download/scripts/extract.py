#!/usr/bin/env python3
"""Extract WeChat article content from HTML"""
import sys
import re
import html

def extract_article(html_content):
    """Extract title, author, and content from WeChat HTML"""
    
    # Extract title from og:title
    title_match = re.search(r'<meta[^>]*property="og:title"[^>]*content="([^"]+)"', html_content)
    title = title_match.group(1) if title_match else ""
    
    # Extract author/nickname
    author_match = re.search(r'var\s+nickname\s*=\s*"([^"]+)"', html_content)
    author = author_match.group(1) if author_match else ""
    
    # Alternative author from js_name
    if not author:
        js_name_match = re.search(r'id="js_name"[^>]*>([^<]+)', html_content)
        author = js_name_match.group(1).strip() if js_name_match else ""
    
    # Extract js_content div (handle nested divs)
    content_match = re.search(r'id="js_content"[^>]*>(.*?)</div>', html_content, re.DOTALL)
    content_html = content_match.group(1) if content_match else ""
    
    # Extract image URLs
    images = re.findall(r'data-src="(https?://[^"]+)"', content_html)
    
    # Convert HTML to plain text (basic)
    content_text = content_html
    content_text = re.sub(r'<br\s*/?>', '\n', content_text)
    content_text = re.sub(r'<p[^>]*>', '\n', content_text)
    content_text = re.sub(r'</p>', '\n', content_text)
    content_text = re.sub(r'<strong[^>]*>', '**', content_text)
    content_text = re.sub(r'</strong>', '**', content_text)
    content_text = re.sub(r'<[^>]+>', '', content_text)
    content_text = html.unescape(content_text)
    content_text = re.sub(r'\n\s*\n', '\n\n', content_text)
    content_text = content_text.strip()
    
    # Check if blocked
    is_blocked = (
        "环境异常" in html_content or
        "wappoc_appmsgcaptcha" in html_content or
        "Weixin Official" in title or
        len(content_text) < 100
    )
    
    return {
        "title": title,
        "author": author,
        "content": content_text,
        "content_html": content_html,
        "images": images,
        "is_blocked": is_blocked,
        "content_len": len(content_html)
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 extract.py <html_file> [output_json]")
        sys.exit(1)
    
    html_file = sys.argv[1]
    output_json = sys.argv[2] if len(sys.argv) > 2 else None
    
    with open(html_file, 'r', encoding='utf-8') as f:
        html_content = f.read()
    
    result = extract_article(html_content)
    
    if output_json:
        import json
        with open(output_json, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        print(f"Saved to: {output_json}")
    else:
        print(f"Title: {result['title']}")
        print(f"Author: {result['author']}")
        print(f"Content length: {result['content_len']}")
        print(f"Images: {len(result['images'])}")
        print(f"Blocked: {result['is_blocked']}")
    
    sys.exit(1 if result['is_blocked'] else 0)