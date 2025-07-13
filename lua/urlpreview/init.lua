local state = require("urlpreview.state")

local M = {}

---@class UrlPreviewConfig
---@field node_command string

---@type UrlPreviewConfig
M.config = {
    node_command = "node",
    auto_preview = true,
}

M.setup = function(cfg)
    -- M.config = vim.tbl_extend("force", M.config, cfg or {})
end


local augroup = vim.api.nvim_create_augroup("urlpreview", {})

vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    callback = function()
        if not state.is_focussed() then
            state.remove_display()
        end
    end
})

---@param focus? boolean Whether to focus the preview window if it already exists
M.preview_url = function(focus)
    if focus and state.has_display() then
        state.focus_display()
        return
    end

    if state.get_url_at_cursor() then
        state.fetch_url_description(function()
            if state.cursor_is_unmoved() then
                state.show_display()
            end
        end)
    end
end

vim.keymap.set("n", "<leader><c-k>", function() M.preview_url(true) end, {})

if M.config.auto_preview then
    vim.api.nvim_create_autocmd("CursorHold", { callback = M.preview_url })
end

-- https://www.linkedin.com/in/jscott2718/
-- https://fosstodon.org/home
-- https://fosstodon.org/@_wurli
-- https://www.linkedin.com/
-- https://www.youtube.com/watch?v=GBV27hMM2RU
-- https://www.youtube.com
-- https://github.com/wurli/urlpreview.nvim
-- https://github.com/LuaLS/lua-language-server -- Fix: should wrap properly
-- https://www.bbc.co.uk/news

-- vim.print(require("urlpreview").get_stuff(
--     "https://www.youtube.com/watch?v=GBV27hMM2RU",
--     vim.print
-- ))

-- local n_wraps = function()
--     local line = vim.fn.line(".")
--     vim.api.with
-- end


return M
