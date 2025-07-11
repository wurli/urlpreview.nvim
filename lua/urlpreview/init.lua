local find_cursor_link = require("urlpreview.find_cursor_link")
local url_display = require("urlpreview.url_display")

--- www.google.com
local M = {}
M.urls = {}

---@class UrlPreviewConfig
---@field node_command string

---@type UrlPreviewConfig
M.config = {
    node_command = "node",
}


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


---@param url string URL to fetch title and description for
---@param on_complete function Callback once informatino has been fetched. This
---  function will be passed the JSON response which may include fields `title`
---  and `description`.
M.get_stuff = function(url, on_complete)
    local helper = helper_file("get_url_info.js")

    -- I'm not a maniac
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
    if url_display:is_visible() then
        url_display:focus()
    else
        url_display:new()
    end
end

vim.keymap.set("n", "<leader><c-k>", M.preview_url, {})

-- vim.api.nvim_create_autocmd("CursorHold", {
--     callback = M.show_url_info
-- })


-- https://www.linkedin.com/in/jscott2718/
-- https://fosstodon.org/home
-- https://fosstodon.org/@_wurli
-- https://www.linkedin.com/
-- https://www.youtube.com/watch?v=GBV27hMM2RU
-- https://www.youtube.com
-- https://github.com/wurli/urlpreview.nvim
-- vim.print(M.get_stuff("https://github.com/LuaLS/lua-language-server"))
-- https://www.bbc.co.uk/news

-- vim.print(require("urlpreview").get_stuff(
--     "https://www.youtube.com/watch?v=GBV27hMM2RU",
--     vim.print
-- ))


return M
