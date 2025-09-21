local M = {}

local utils = require("urlpreview.utils")
local scrape = require("urlpreview.scrape")

---@class UrlPreviewConfig
---
---If `true` an autocommand will be created to show a preview when the cursor
---rests over an URL. Note, this uses the `CursorHold` event which can take a
---while to trigger if you don't change your `updatetime`, e.g. using
---`vim.opt.updatetime = 500`.
---@field auto_preview? boolean
---
---By default no keymap will be set. If set, this keymap will be applied in
---normal mode and will work when the cursor is over an URL.
---@field keymap? string | boolean
---
---The maximum width to use for the URL preview window.
---@field max_window_width? number
---
---Set to `false` to not apply highlighting
---@field hl_group_title? string | boolean
---
---Set to `false` to not apply highlighting
---@field hl_group_description? string | boolean
---
---Set to `false` to not apply highlighting
---@field hl_group_url? string | boolean
---
---Passed to `vim.api.nvim_open_win()` if provided
---@field window_border? 'none'|'single'|'double'|'rounded'|'solid'|'shadow'|string[]

---@type UrlPreviewConfig
M.config = {
    auto_preview = false,
    keymap = false,
    max_window_width = 100,
    hl_group_title = "@markup.heading",
    hl_group_description = "@markup.quote",
    hl_group_url = "Underlined",
    window_border = nil,
}

---@class UrlPreviewState
---@field url_text? string The URL text. `nil` means the cursor is not over a valid URL.
---@field start_col integer The start column of the URL in the line
---@field end_col integer The end column of the URL in the line
---@field lnum integer The line number where the URL is found
---@field buf integer The buffer number where the URL is found
---@field url_extmark integer The highlight extmark ID used to underline the URL
---@field info_win integer The window ID where the URL info is displayed
---@field info_buf integer The buffer ID where the URL info is displayed
---@field title string The title of the URL
---@field description string The description of the URL

---@class UrlPreviewState
M.data = {
    url_text = nil,
    start_col = 0,
    end_col = 0,
    lnum = 0,
    buf = -1,
    url_extmark = -1,
    info_win = -1,
    info_buf = -1,
    title = "",
    description = "",
}

M.has_display = function()
    return vim.api.nvim_win_is_valid(M.data.info_win)
end

local url_preview_ns = vim.api.nvim_create_namespace("urlpreview")

M.fetch_url_description = function(callback)
    if not M.data.url_text then
        -- Shouldn't ever happen, but just in case
        return
    end

    -- I'm not a maniac
    if M.data.url_text:find("^www") then
        M.data.url_text = "https://" .. M.data.url_text
    end

    scrape(M.data.url_text, vim.schedule_wrap(function(res)
        M.data.title = res.title or ""
        M.data.description = res.description or ""
        if callback then callback() end
    end))
end

---@return boolean result indicating whether an URL was found at the cursor
---  position
M.get_url_at_cursor = function()
    local start_col, end_col = utils.find_cursor_link()

    if not (start_col and end_col) then
        M.data.url_text = nil
        return false
    end

    M.data.start_col = start_col
    M.data.end_col   = end_col
    M.data.lnum      = vim.fn.line(".") - 1
    M.data.buf       = vim.fn.bufnr()
    M.data.url_text  = vim.api.nvim_buf_get_text(0, M.data.lnum, start_col, M.data.lnum, end_col, {})[1]
    return true
end

---Checks whether the cursor has moved away from the URL which was last previewed.
---
---This is needed for a few things:
---* Pulling the title/description might take a second, during which time the
---  user might move the cursor elsewhere. If they've done this, we can just
---  discard the pulled info once we have it.
---* The user might move their cursor around within an URL. We can check if
---  this is the case using this function.
---@return boolean
M.cursor_is_unmoved = function()
    if not M.data.url_text then
        return false
    end

    if vim.fn.bufnr() ~= M.data.buf then
        return false
    end

    local cur_lnum = vim.fn.line(".") - 1
    if M.data.lnum ~= cur_lnum then
        return false
    end

    local cur_col = vim.fn.col(".")
    return M.data.start_col < cur_col and cur_col <= M.data.end_col
end

M.show_display = function()
    if M.has_display() then
        return
    end

    if M.config.hl_group_url and not M.url_extmark_is_active() then
        M.data.url_extmark = vim.api.nvim_buf_set_extmark(
            M.data.buf,
            url_preview_ns,
            M.data.lnum,
            M.data.start_col,
            {
                end_col = M.data.end_col,
                hl_group = M.config.hl_group_url,
                url = M.data.url_text,
            }
        )
    end

    local width        = math.min(math.max(#M.data.title + 2, #M.data.description + 2), 100)
    local title        = utils.str_wrap(M.data.title or "", M.config.max_window_width)
    local description  = utils.str_wrap(M.data.description or "", M.config.max_window_width)

    local text = {}
    for _, x in ipairs(title) do table.insert(text, x) end
    for _, x in ipairs(description) do table.insert(text, x) end

    local win_height   = #text

    if win_height > 0 then
        M.data.info_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(M.data.info_buf, 0, 1, false, text)

        M.data.info_win = vim.api.nvim_open_win(M.data.info_buf, false, {
            relative = "cursor",
            width = width,
            height = win_height,
            row = 1,
            col = 0,
            focusable = true,
            style = "minimal",
            border = M.config.window_border,
        })

        if M.config.hl_group_title then
            vim.api.nvim_buf_set_extmark(M.data.info_buf, url_preview_ns, 0, 0, {
                hl_group = M.config.hl_group_title,
                end_row = #title,
            })
        end
        if M.config.hl_group_description then
            vim.api.nvim_buf_set_extmark(M.data.info_buf, url_preview_ns, #title, 0, {
                hl_group = M.config.hl_group_description,
                end_row = win_height,
            })
        end

        vim.wo[M.data.info_win].number         = false
        vim.wo[M.data.info_win].relativenumber = false
        vim.wo[M.data.info_win].cursorline     = false
        vim.wo[M.data.info_win].linebreak      = true
        vim.bo[M.data.info_buf].buftype        = "nofile"
        vim.bo[M.data.info_buf].modifiable     = false

        vim.keymap.set(
            "n", "q",
            function()
                vim.cmd.close()
                M.remove_display()
            end,
            {
                buffer = M.data.info_buf,
                noremap = true,
                silent = true,
                nowait = true
            }
        )
    end
end

M.url_extmark_is_active = function()
    local pos = vim.api.nvim_buf_get_extmark_by_id(M.data.buf, url_preview_ns, M.data.url_extmark, {})
    return #pos > 0
end

M.remove_url_extmark = function()
    vim.api.nvim_buf_del_extmark(M.data.buf, url_preview_ns, M.data.url_extmark)
end

M.remove_display = function()
    M.data.url_text = nil
    if vim.api.nvim_buf_is_valid(M.data.buf) then
        M.remove_url_extmark()
    end
    if M.has_display() then
        vim.api.nvim_win_close(M.data.info_win, true)
    end
end

M.is_focussed = function()
    return vim.fn.bufnr() == M.data.info_buf
end

M.focus_display = function()
    if M.has_display() then
        vim.api.nvim_set_current_win(M.data.info_win)
    end
end

return M
