#!/usr/bin/env node

const https = require('https');
const http = require('http');
const { URL } = require('url');

const targetUrl = process.argv[2];

if (!targetUrl) {
    console.error(JSON.stringify({ error: 'Please provide a URL as an argument.' }));
    process.exit(1);
}

function fetchPage(url, callback) {
    const parsedUrl = new URL(url);
    const lib = parsedUrl.protocol === 'https:' ? https : http;

    lib.get(url, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => callback(null, data));
    }).on('error', (err) => {
            callback(err);
        });
}

function extractMeta(html) {
    const titleMatch = html.match(/<title[^>]*>([^<]*)<\/title>/i);
    const metaMatch = html.match(/<meta[^>]+name=["']description["'][^>]*content=["']([^"']*)["']/i);

    return {
        title: titleMatch ? titleMatch[1].trim() : null,
        description: metaMatch ? metaMatch[1].trim() : null
    };
}

fetchPage(targetUrl, (err, html) => {
    if (err) {
        console.error(JSON.stringify({ error: 'Failed to fetch page', details: err.message }));
        process.exit(1);
    }

    const meta = extractMeta(html);
    console.log(JSON.stringify(meta, null, 2));
});
