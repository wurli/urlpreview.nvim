--- www.google.com
local M = {}

M.win = -1
---@type UrlDisplayStuff[]
M.urls = {}

local url_preview_ns = vim.api.nvim_create_namespace("urlpreview")

---@class UrlDisplayStuff
---@field url string The URL text
---@field start_col integer The start column of the URL in the line
---@field end_col integer The end column of the URL in the line
---@field line integer The line number where the URL is found
---@field buf integer The buffer number where the URL is found
---@field hl_extmark integer The highlight extmark ID used to underline the URL
---@field info_win integer The window ID where the URL info is displayed
---@field info_buf integer The buffer ID where the URL info is displayed
---@field title string The title of the URL
---@field description string The description of the URL

---@class UrlDisplayStuff
local url_display = {
    url = "",
    start_col = 0,
    end_col = 0,
    line = 0,
    buf = -1,
    hl_extmark = -1,
    info_win = -1,
    info_buf = -1,
    title = "",
    description = "",
}

function url_display:is_visible()
    return vim.api.nvim_win_is_valid(self.info_win)
end

function url_display:remove()
    vim.api.nvim_buf_del_extmark(self.buf, url_preview_ns, self.hl_extmark)
    if self:is_visible() then
        vim.api.nvim_win_close(self.info_win, true)
    end
end

url_display.__index = url_display

function url_display:new(line, start_col, end_col, title, description)
    local out = setmetatable({}, self)

    title       = title or ""
    description = description or ""

    out.url       = vim.api.nvim_buf_get_text(0, line, start_col, line, end_col, {})[1]
    out.start_col = start_col
    out.end_col   = end_col
    out.line      = line
    out.buf       = vim.fn.bufnr()

    out.hl_extmark = vim.api.nvim_buf_set_extmark(out.buf, url_preview_ns, out.line, out.start_col, {
        end_col = out.end_col,
        hl_group = "Underlined"
    })

    local width        = math.min(math.max(#title + 2, #description + 2), 100)
    local title_width  = vim.fn.strdisplaywidth(title)
    local desc_width   = vim.fn.strdisplaywidth(description)
    local title_height = math.ceil(title_width / width)
    local desc_height  = math.ceil(desc_width / width)
    local win_height   = title_height + desc_height

    if win_height > 0 then
        out.info_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(out.info_buf, 0, 2, false, { title, description })

        out.info_win = vim.api.nvim_open_win(out.info_buf, false, {
            relative = "cursor",
            width = width,
            height = win_height,
            row = 1,
            col = 0,
            focusable = true,
            style = "minimal",
        })

        vim.api.nvim_buf_set_extmark(out.info_buf, url_preview_ns, 1, 0, {
            hl_group = "@markup.quote",
            end_row = 2,
        })

        vim.wo[out.info_win].number         = false
        vim.wo[out.info_win].relativenumber = false
        vim.wo[out.info_win].cursorline     = false
        vim.wo[out.info_win].linebreak      = true
        vim.bo[out.info_buf].buftype        = "nofile"

        vim.api.nvim_buf_set_keymap(out.info_buf, "n", "q", "<cmd>close<cr>", {
            noremap = true,
            silent = true,
            nowait = true
        })
    end

    return out
end

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
    table.sort(matches, function(m1, m2) return m1[1] < m2[1] end)

    for _, m in ipairs(matches) do
        if m[1] <= col and col <= m[2] then
            M.cur_url = {
                start_col = m[1] - 1,
                end_col = m[2],
                line = vim.fn.line("."),
                buf = vim.fn.bufnr()
            }
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


M.get_stuff = function(url, on_complete)
    local helper = helper_file("get_url_info.js")

    if url:find("^www") then
        url = "https://" .. url
    end

    local cmd = { "node", helper, url }

    vim.system(cmd, { text = true }, function(res)
        local json = {}
        if res.code == 0 then
            json = vim.json.decode(res.stdout)
            for k, v in pairs(json) do
                if v == vim.NIL then
                    json[k] = nil
                else
                    json[k] = v:gsub("[\n\r]", " ")
                end
            end
        end

        vim.schedule(function() on_complete(json or {}) end)
    end)
end

M.show_url_info = function()
    -- We shouldn't display another window if one already exists, otherwise our
    -- autocmd to close the window on cursor move will cease to apply to the
    -- pre-existing window.
    if vim.api.nvim_win_is_valid(M.win) then return end

    local link_start, link_end = find_cursor_link()
    if not link_start then return end

    local lnum = vim.fn.line(".") - 1
    local url = vim.api.nvim_buf_get_text(0, lnum, link_start, lnum, link_end, {})[1]

    M.get_stuff(url, function(json)
        local cur_line = vim.fn.line(".") - 1
        local cur_col = vim.fn.col(".")

        local cursor_is_still_on_link = cur_line == lnum
            and link_start < cur_col and cur_col <= link_end

        if not cursor_is_still_on_link then
            return
        end

        table.insert(M.urls, url_display:new(
            lnum,
            link_start,
            link_end,
            json.title,
            json.description
        ))
    end)
end

vim.api.nvim_create_autocmd("CursorMoved", {
    group = vim.api.nvim_create_augroup("urlpreview", {}),
    callback = function()
        -- vim.api.nvim_buf_del_extmark(M.cur_url.buf, ns, M.cur_url.hl_extmark)
        -- if vim.api.nvim_get_current_win() == M.win then return end
        -- if vim.api.nvim_win_is_valid(M.win) then vim.api.nvim_win_close(M.win, true) end
        for _, url in pairs(M.urls) do url:remove() end
        M.urls = {}
    end
})

M.focus_url_info = function()
    if vim.api.nvim_win_is_valid(M.win) then
        vim.api.nvim_set_current_win(M.win)
    end
end

M.preview_url = function()
    if vim.api.nvim_win_is_valid(M.win) then
        M.focus_url_info()
    else
        M.show_url_info()
    end
end

vim.keymap.set("n", "<leader><c-k>", M.preview_url, {})

vim.api.nvim_create_autocmd("CursorHold", {
    callback = M.show_url_info
})


-- https://www.linkedin.com/in/jscott2718/
-- https://fosstodon.org/home
-- https://fosstodon.org/@_wurli
-- https://www.linkedin.com/
-- https://www.youtube.com/watch?v=GBV27hMM2RU
-- https://www.youtube.com
-- https://github.com/wurli/urlpreview.nvim
-- vim.print(M.get_stuff("https://github.com/LuaLS/lua-language-server"))
-- https://www.bbc.co.uk/news

-- vim.print(require("urlpreview").urls)

return M
