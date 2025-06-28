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

local url_preview_ns = vim.api.nvim_create_namespace("urlpreview")

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

return url_display

