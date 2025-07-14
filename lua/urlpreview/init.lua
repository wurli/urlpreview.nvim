local state = require("urlpreview.state")
local config = state.config

local M = {}

M.setup = function(cfg)
    for k, v in pairs(cfg or {}) do config[k] = v end
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

vim.keymap.set("n", "<leader>K", function() M.preview_url(true) end, {})

if config.auto_preview then
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
-- https://w3things.com/blog/open-graph-meta-tags/?utm_source=chatgpt.com
-- https://ahrefs.com/blog/open-graph-meta-tags/?utm_source=chatgpt.com
-- https://www.digitalocean.com/community/tutorials/how-to-add-twitter-card-and-open-graph-social-metadata-to-your-webpage-with-html?utm_source=chatgpt.com
-- https://davidwalsh.name/twitter-cards
-- https://en.wikipedia.org/wiki/Meta_element
-- https://www.instagram.com/jpg_scott/

-- vim.print(vim.fn.nr2char(tonumber("1f90f", 16)))
-- vim.print(tonumber("1f90f", 16))

-- vim.print(require("urlpreview.html_entities")["&quot;"])

return M
