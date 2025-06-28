#!/usr/bin/env node

const https = require('https');
const http = require('http');
const cheerio = require('cheerio');
const { URL } = require('url');

function fetchHTML(url) {
    return new Promise((resolve, reject) => {
        const parsedUrl = new URL(url);
        const protocol = parsedUrl.protocol === 'https:' ? https : http;

        protocol.get(url, (response) => {
            if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
                // Handle redirects
                fetchHTML(response.headers.location).then(resolve).catch(reject);
                return;
            }

            if (response.statusCode !== 200) {
                reject(new Error(`Request failed with status code ${response.statusCode}`));
                return;
            }

            let data = '';
            response.on('data', (chunk) => {
                data += chunk;
            });

            response.on('end', () => {
                resolve(data);
            });
        }).on('error', (err) => {
                reject(err);
            });
    });
}

async function extractMetadata(url) {
    try {
        // Fetch HTML content using built-in modules
        const html = await fetchHTML(url);

        // Load HTML with cheerio
        const $ = cheerio.load(html);

        // Extract title and description
        const title = $('title').text();
        const description = $('meta[name="description"]').attr('content') ||
            $('meta[property="og:description"]').attr('content') ||
            '';

        // Create result object
        const result = {
            title,
            description
        };

        // Print result as JSON
        console.log(JSON.stringify(result, null, 2));

        return result;
    } catch (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
}

// Check if URL is provided as command line argument
if (process.argv.length < 3) {
    console.error('Usage: extract-metadata <url>');
    process.exit(1);
}

const url = process.argv[2];
extractMetadata(url);
