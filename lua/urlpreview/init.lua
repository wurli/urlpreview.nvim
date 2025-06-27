--- www.google.comlink-info"
local M = {}

M.urls = {}

---@class UrlPreviewConfig
---@field node_command string

---@type UrlPreviewConfig
M.config = {
    node_command = "node",
}

local url_body_pattern = "[%w@:%%._+~#=/%-?&]*"
local url_prefix_patterns = {
    http = "https?://",
    www = "www%.",
}

local gfind = function(x, pattern)
    local out = {}

    local init = 1

    while true do
        local start, stop = x:find(pattern, init)
        if start == nil then break end
        table.insert(out, { start, stop })
        init = stop + 1
    end

    return out
end

local find_links = function(line)
    local matches = vim.iter(url_prefix_patterns)
        :map(function(prefix) return prefix .. url_body_pattern end)
        :map(function(pattern) return gfind(line, pattern) end)
        :totable()

    -- Annoyingly the default iter:extend() doesn't seem to work for this
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
    table.sort(matches, function(m) return m[2] - m[1] end)

    for _, m in ipairs(matches) do
        if m[1] <= col and col <= m[2] then
            return m[1] - 1, m[2]
        end
    end
end


local helper_file = function(file)
    local curr_file = debug.getinfo(1).source:gsub("^@", "")
    local pkg_dir = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(curr_file)))
    local path = vim.fs.joinpath(pkg_dir, "helpers", file)
    if vim.fn.filereadable(path) == 0 then
        error("Can't find helper file " .. path)
    end
    return path
end

M.setup = function(cfg)
    -- M.config = vim.tbl_extend("force", M.config, cfg or {})
end

M.get_stuff = function(url)
    local helper = helper_file("get_stuff.js")

    local cmd = { "node", helper, url }

    local res = vim.system(cmd, { text = true }):wait()
    table.insert(M.urls, res)

    local out = vim.json.decode(res.stdout)
    for k, v in pairs(out) do
        if v == vim.NIL then
            out[k] = nil
        end
    end

    return out
end

local display_curr_link_info = function()
    local link_start, link_end = find_cursor_link()
    if not link_start then return end

    local ns = vim.api.nvim_create_namespace("link-info")
    local lnum = vim.fn.line(".") - 1

    local mark = vim.api.nvim_buf_set_extmark(0, ns, lnum, link_start, {
        end_col = link_end,
        hl_group = "Underlined"
    })

    local url = vim.api.nvim_buf_get_text(0, lnum, link_start, lnum, link_end, {})[1]

    local info = M.get_stuff(url)

    local temp_buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(temp_buf, 0, 2, false, { info.title or "bla", info.description or "bla bla" })

    local win = vim.api.nvim_open_win(temp_buf, false, {
        relative = "cursor",
        width = 140,
        height = 2,
        row = 1,
        col = 0,
        focusable = true,
    })

    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].cursorline = false

    vim.api.nvim_create_autocmd("CursorMoved", {
        group = ns,
        once = true,
        callback = function()
            vim.api.nvim_buf_del_extmark(0, ns, mark)
            vim.api.nvim_win_close(win, true)
        end
    })
end

vim.keymap.set("n", "<leader><c-k>", display_curr_link_info, {})

vim.api.nvim_create_autocmd("CursorHold", {
    callback = display_curr_link_info
})

-- https://www.linkedin.com/in/jscott2718/
-- https://fosstodon.org/home
-- https://fosstodon.org/@_wurli
-- https://www.linkedin.com/
-- https://www.youtube.com
-- vim.print(M.get_stuff("https://github.com/LuaLS/lua-language-server"))

vim.print(require("urlpreview").urls)

return M
