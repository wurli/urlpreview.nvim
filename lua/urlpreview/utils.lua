local M = {}

local url_body_pattern = "[%w@:%%._+~#=/%-?&]*"
local url_prefix_patterns = {
    http = "https?://",
    www = "www%.",
}

local gfind = function(x, pattern)
    local matches = {}

    local init = 1

    while true do
        local start, stop = x:find(pattern, init)
        if start == nil then break end
        table.insert(matches, { start, stop })
        init = stop + 1
    end

    return matches
end

local find_links = function(line)
    local matches = vim.iter(url_prefix_patterns)
        :map(function(prefix) return prefix .. url_body_pattern end)
        :map(function(pattern) return gfind(line, pattern) end)
        :totable()

    -- Annoyingly the default iter:flatten() doesn't seem to work for this
    -- use-case
    local out = {}
    for _, i in ipairs(matches) do
        for _, j in ipairs(i) do
            table.insert(out, j)
        end
    end

    return out
end

M.find_cursor_link = function()
    local line = vim.fn.getline(".")
    local col = vim.fn.col(".")

    local matches = find_links(line)
    table.sort(matches, function(m1, m2) return m1[1] < m2[1] end)

    for _, m in ipairs(matches) do
        if m[1] <= col and col <= m[2] then
            return m[1] - 1, m[2]
        end
    end
end


---Wrap a string based on length
---
---Won't wrap cases where there are words with more than `width` chars, but
---these are fine I think as vim will usually wrap them anyway.
---
---NB, we use wrapping because:
---1. If we don't it's hard to figure out how tall to make the preview window
---2. It makes the window a bit more intuitive to navigate when focussed
---
---@param x string Text to wrap
---@param width? number Defaults to 100
---@return string[]
M.str_wrap = function(x, width)
    width = width or 100
    local lines = { "" }

    for s in x:gmatch("(%S+)") do
        local sep = lines[#lines] == "" and "" or " "
        local concat = lines[#lines] .. sep .. s

        if vim.fn.strdisplaywidth(concat) <= width then
            lines[#lines] = concat
        else
            table.insert(lines, s)
        end
    end

    local out = {}
    for _, l in ipairs(lines) do
        if l ~= "" then table.insert(out, l) end
    end

    return out
end

return M
