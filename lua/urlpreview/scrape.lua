local html_entities = require("urlpreview.html_entities")

--- This is arguably a bit of a hack-job but really what we're trying to do
--- here is very simple, so a bit of pattern matching seems preferable to other
--- obvious solutions e.g. taking on some massive node.js dependency.
local scrape = function(url, callback)
    vim.system(
        { "curl", url, "--location" },
        { text = true },
        vim.schedule_wrap(function(res)
            if res.code ~= 0 then
                return
            end

            local html = res.stdout

            if not html then
                return
            end

            local patterns = {
                -- For readability:
                --   Double space ~ one or more spaces
                --   Single space ~ zero or more spaces
                title = {
                    "<title [^>]*> ([^>]*) </title>",
                },
                --- For each item:
                --   1. Look for the first pattern
                --   2. If found, look within the result for the second pattern
                --   ...
                --   n. If found, look within the result for the nth pattern
                description1 = {
                    '<meta  [^>]*name="description"[^>]*>',
                    'content="([^"]*)"',
                },
                description2 = {
                    '<meta  [^>]*property="og:description"[^>]*>',
                    'content="([^"]*)"',
                },
                description3 = {
                    '<meta  [^>]*name="twitter:description"[^>]*>',
                    'content="([^"]*)"',
                }
            }

            -- Replace spaces with whitespace patterns
            for k, vx in pairs(patterns) do
                for i, vy in ipairs(vx) do
                    patterns[k][i] = vy:gsub("  ", "%%s+"):gsub(" ", "%%s*")
                end
            end

            -- Helper to iteratively cut down page html using a sequence of lua
            -- patterns
            local extract_pattern = function(p)
                local out = html
                for _, pi in ipairs(p) do
                    local out2 = out:match(pi)
                    if not out2 then out2 = out:match(pi:gsub('"', "'")) end
                    if not out2 then return end
                    out = out2
                end
                return out
            end

            local out = {
                title = extract_pattern(patterns.title),
                description = extract_pattern(patterns.description1),
            }

            if not out.description then out.description = extract_pattern(patterns.description2) end
            if not out.description then out.description = extract_pattern(patterns.description3) end

            -- Replace html numbered character entities, e.g. `&#40;` = `@`
            for k, v in pairs(out) do
                out[k] = v:gsub("&#(%d+);", function(n)
                    return string.char(tonumber(n))
                end)
            end

            -- Replace html unicode characters, e.g. emojis
            for k, v in pairs(out) do
                out[k] = v:gsub("&#x([0-9a-zA-Z]+);", function(n)
                    return vim.fn.nr2char(tonumber(n, 16))
                end)
            end

            -- Replace html named character entities, e.g. `&commat;` = `@`
            for k, v in pairs(out) do
                out[k] = v:gsub("&[a-zA-Z]+;", function(e)
                    return html_entities[e] or e
                end)
            end

            if callback then callback(out) end
        end)
    )
end


return scrape
