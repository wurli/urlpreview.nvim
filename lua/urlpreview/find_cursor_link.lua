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

local find_cursor_link = function()
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

return find_cursor_link
