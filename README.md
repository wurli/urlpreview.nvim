# urlpreview.nvim

A Neovim plugin to show basic information about webpages in-editor 💫



## Installation

Using Lazy.nvim:

``` lua
---
---
---@field max_window_width? number
---
---Set to `""` to not apply highlighting
---@field hl_group_title? string
---
---Set to `""` to not apply highlighting
---@field hl_group_description? string
---
---Set to `""` to not apply highlighting
---@field hl_group_url? string

---@type UrlPreviewConfig
return {
    -- If `true` an autocommand will be created to show a preview when the cursor
    -- rests over an URL. Note, this uses the `CursorHold` event which can take a
    -- while to trigger if you don't change your `updatetime`, e.g. using
    -- `vim.opt.updatetime = 500`.
    auto_preview = true,
    -- By default no keymap will be set. If set, this keymap will be applied in
    -- normal mode and will work when the cursor is over an URL.
    keymap = "<leader>K",
    -- The maximum width to use for the URL preview window.
    max_window_width = 100,
    -- Highlight groups; use `false` if you don't want highlights.
    hl_group_title = "@markup.heading",
    hl_group_description = "@markup.quote",
    hl_group_url = "Underlined",
}
```

## Features

*   Lightweight: no external dependencies besides plain old `curl` 💨

*   Non-blocking: Neovim continues to work as normal while waiting for the
    request to return.

*   Intelligent: uses a page's `<title>` for the main heading, then checks in
    turn for `<meta name="description">`, `<meta property="os:description">` and
    `<meta name="twitter:description">` for the description.

