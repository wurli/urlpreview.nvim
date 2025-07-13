---@class UrlPreviewConfig
---@field node_command? string
---@field auto_preview? boolean
---@field max_window_width? number
---@field hl_group_title? string Set to `""` to not apply highlighting
---@field hl_group_description? string Set to `""` to not apply highlighting

---@type UrlPreviewConfig
return {
    node_command = "node",
    auto_preview = true,
    max_window_width = 100,
    hl_group_title = "@markup.heading",
    hl_group_description = "@markup.quote",
}

