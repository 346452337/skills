// CloakBrowser fetch script for WeChat articles - improved version
// Usage: node cloakbrowser-fetch.mjs <url> <output_json_file>

import puppeteer from 'puppeteer-core';
import fs from 'fs';

const CLOAKBROWSER_PATH = "/root/.cloakbrowser/chromium-146.0.7680.177.4/chrome";
const TIMEOUT = 90000;

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function fetchWeChatArticle(url) {
    console.log(`Starting CloakBrowser for: ${url}`);
    
    const browser = await puppeteer.launch({
        executablePath: CLOAKBROWSER_PATH,
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-gpu',
            '--disable-dev-shm-usage',
            '--disable-blink-features=AutomationControlled',
            '--disable-web-security',
            '--disable-features=IsolateOrigins,site-per-process',
        ]
    });

    const page = await browser.newPage();

    try {
        // Set realistic user agent
        await page.setUserAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36');
        
        // Set extra headers
        await page.setExtraHTTPHeaders({
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Cache-Control': 'no-cache',
        });

        // Override navigator properties for stealth
        await page.evaluateOnNewDocument(() => {
            Object.defineProperty(navigator, 'webdriver', { get: () => false });
            Object.defineProperty(navigator, 'languages', { get: () => ['zh-CN', 'zh', 'en'] });
            Object.defineProperty(navigator, 'platform', { get: () => 'MacIntel' });
        });

        // Navigate with longer wait
        console.log('Navigating...');
        const response = await page.goto(url, {
            waitUntil: 'networkidle2',
            timeout: TIMEOUT
        });

        // Wait for content to load
        console.log('Waiting for content...');
        await sleep(5000);

        // Try to wait for js_content
        try {
            await page.waitForSelector('#js_content', { timeout: 10000 });
            console.log('js_content found');
        } catch (e) {
            console.log('js_content timeout, proceeding anyway');
        }

        // Additional wait for dynamic content
        await sleep(3000);

        // Get title
        const title = await page.title();
        console.log(`Title: ${title}`);

        // Get HTML content
        const html = await page.content();

        // Extract js_content
        const content = await page.evaluate(() => {
            const el = document.querySelector('#js_content');
            return el ? el.innerText : '';
        });

        // Extract author
        const author = await page.evaluate(() => {
            const el = document.querySelector('#js_name');
            return el ? el.innerText.trim() : '';
        });

        // Check for captcha - improved detection
        const hasCaptcha = 
            title.includes('微信公众平台') ||
            title.includes('Weixin Official Accounts') ||
            html.includes('环境异常') ||
            html.includes('wappoc_appmsgcaptcha') ||
            content.length < 100;

        // Extract image URLs
        const images = await page.evaluate(() => {
            const imgs = document.querySelectorAll('#js_content img[data-src], #js_content img[src]');
            return Array.from(imgs).map(img => {
                const src = img.getAttribute('data-src') || img.getAttribute('src');
                return src && !src.startsWith('data:') ? src : null;
            }).filter(Boolean);
        });

        const result = {
            status: response.status(),
            title: title,
            author: author,
            content: content,
            html: html,
            images: images,
            hasCaptcha: hasCaptcha,
            contentLength: content.length,
            url: url
        };

        await browser.close();
        
        if (hasCaptcha) {
            console.log('BLOCKED by WeChat');
        } else {
            console.log(`SUCCESS: ${content.length} chars, ${images.length} images`);
        }
        
        return result;

    } catch (error) {
        console.log(`ERROR: ${error.message}`);
        await browser.close();
        return {
            status: 0,
            error: error.message,
            title: '',
            author: '',
            content: '',
            html: '',
            images: [],
            hasCaptcha: true,
            url: url
        };
    }
}

// Main
const url = process.argv[2];
const outputFile = process.argv[3];

if (!url) {
    console.error('Usage: node cloakbrowser-fetch.mjs <url> [output_file]');
    process.exit(1);
}

fetchWeChatArticle(url).then(result => {
    if (outputFile) {
        const json = JSON.stringify(result, null, 2);
        fs.writeFileSync(outputFile, json);
        console.log(`Saved: ${outputFile}`);
    } else {
        console.log(JSON.stringify(result, null, 2));
    }
    
    process.exit(result.hasCaptcha ? 1 : 0);
}).catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
});