local find_cursor_link = require("urlpreview.find_cursor_link")

local helper_file = function(file)
    local curr_file = debug.getinfo(1).source:gsub("^@", "")
    local pkg_dir = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(curr_file)))
    local path = vim.fs.joinpath(pkg_dir, "helpers", file)
    if vim.fn.filereadable(path) == 0 then
        error("Can't find helper file " .. path)
    end
    return path
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
local str_wrap = function(x, width)
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

local M = {}

---@class UrlPreviewState
---@field url_text? string The URL text. `nil` means the cursor is not over a valid URL.
---@field start_col integer The start column of the URL in the line
---@field end_col integer The end column of the URL in the line
---@field lnum integer The line number where the URL is found
---@field buf integer The buffer number where the URL is found
---@field hl_extmark integer The highlight extmark ID used to underline the URL
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
    hl_extmark = -1,
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
    local helper = helper_file("get_url_info.js")

    if not M.data.url_text then
        -- Shouldn't ever happen, but just in case
        return
    end

    -- I'm not a maniac
    if M.data.url_text:find("^www") then
        M.data.url_text = "https://" .. M.data.url_text
    end

    local cmd = { "node", helper, M.data.url_text }

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

        M.data.title = json.title or ""
        M.data.description = json.description or ""

        if callback then vim.schedule(callback) end
    end)
end

---@return boolean result indicating whether an URL was found at the cursor
---  position
M.get_url_at_cursor = function()
    local start_col, end_col = find_cursor_link()

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

    M.data.hl_extmark = vim.api.nvim_buf_set_extmark(
        M.data.buf,
        url_preview_ns,
        M.data.lnum,
        M.data.start_col,
        {
            end_col = M.data.end_col,
            hl_group = "Underlined",
            url = M.data.url_text,
        }
    )

    local width        = math.min(math.max(#M.data.title + 2, #M.data.description + 2), 100)
    local title        = str_wrap(M.data.title or "", width)
    local description  = str_wrap(M.data.description or "", width)

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
        })

        vim.api.nvim_buf_set_extmark(M.data.info_buf, url_preview_ns, #title, 0, {
            hl_group = "@markup.quote",
            end_row = win_height,
        })

        vim.wo[M.data.info_win].number         = false
        vim.wo[M.data.info_win].relativenumber = false
        vim.wo[M.data.info_win].cursorline     = false
        vim.wo[M.data.info_win].linebreak      = true
        vim.bo[M.data.info_buf].buftype        = "nofile"

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

M.remove_display = function()
    M.data.url_text = nil
    if vim.api.nvim_buf_is_valid(M.data.buf) then
        vim.api.nvim_buf_del_extmark(M.data.buf, url_preview_ns, M.data.hl_extmark)
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
