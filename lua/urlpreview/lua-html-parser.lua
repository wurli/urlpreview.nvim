local function decode_html(str)
    -- Table of HTML entities to decode
    local known_codes = {
        ["&amp;"] = "&",
        ["&lt;"] = "<",
        ["&gt;"] = ">",
        ["&quot;"] = '"',
        ["&apos;"] = "'",
        ["&nbsp;"] = ""
    }

    local html_code_pattern = "(&.-;)"

    -- Function to process each HTML entity
    local function decode(code)
        -- First check if it's a named entity in our table
        if known_codes[code] then
            return known_codes[code]
        end

        -- If not in table, try to decode as numeric entity
        return code:gsub("&#(%d+);", function(num)
            ---@diagnostic disable-next-line: param-type-mismatch
            return string.char(tonumber(num))
        end)
    end

    -- Replace all HTML entities with their corresponding characters
    return str:gsub(html_code_pattern, decode)
end

-- Function to extract title and description from HTML content
local extract_webpage_info = function(html)
    if not html or html == "" then
        return
    end

    -- Extract title
    local title = html:match("<title>(.-)</title>")
    title = title and decode_html(title) or "No title found"

    -- Extract description
    local description = html:match('<meta%s+name="description"%s+content="(.-)"') or
        html:match('<meta%s+content="(.-)"%s+name="description"')
    description = description and decode_html(description) or "No description found"

    return {
        title = title,
        description = description
    }
end

-- https://www.linkedin.com/in/jscott2718/
-- https://fosstodon.org/home
-- https://fosstodon.org/@_wurli
-- https://www.linkedin.com/
-- https://www.youtube.com/watch?v=GBV27hMM2RU
-- https://www.youtube.com
-- https://github.com/wurli/urlpreview.nvim
-- vim.print(M.get_stuff("https://github.com/LuaLS/lua-language-server"))
-- https://www.bbc.co.uk/news

local out = vim.system(
    {
        "curl",
        "https://www.youtube.com/watch?v=GBV27hMM2RU",
    },
    { text = true }
):wait().stdout


vim.print(extract_webpage_info(out))
