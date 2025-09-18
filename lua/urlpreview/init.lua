local state = require("urlpreview.state")
local config = state.config

local M = {}

M.setup = function(cfg)
    for k, v in pairs(cfg or {}) do config[k] = v end

    if config.auto_preview then
        vim.api.nvim_create_autocmd("CursorHold", {
            callback = function() M.preview_url() end
        })
    end

    if config.keymap then
        vim.keymap.set(
            "n",
            ---@diagnostic disable-next-line: param-type-mismatch
            config.keymap,
            function() M.preview_url(true) end,
            { desc = "URL preview" }
        )
    end

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

---Show a pop-up with information about a webpage
---
---@param focus? boolean Whether to focus the preview window if it already exists
M.preview_url = function(focus)
    if focus == nil then focus = false end
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


-- https://github.com/wurli/urlpreview.nvim
-- https://fosstodon.org/@_wurli
-- https://www.linkedin.com/
-- https://www.youtube.com/watch?v=tX4TLFMly5U
-- https://www.bbc.co.uk/news
-- https://w3things.com/blog/open-graph-meta-tags/?utm_source=chatgpt.com
-- https://ahrefs.com/blog/open-graph-meta-tags/?utm_source=chatgpt.com
-- https://www.digitalocean.com/community/tutorials/how-to-add-twitter-card-and-open-graph-social-metadata-to-your-webpage-with-html?utm_source=chatgpt.com
-- https://davidwalsh.name/twitter-cards
-- https://excalidraw.com/
-- https://r4ds.hadley.nz/
-- https://trafilatura.readthedocs.io/en/latest/index.html

return M
