local config = vim.env.XDG_CONFIG_HOME and vim.env.XDG_CONFIG_HOME ~= "" and vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")
local runtime = config .. "/omarchy/runtime/neovim-theme.lua"
if not (vim.uv or vim.loop).fs_stat(runtime) then
  return
end

local ok, theme = pcall(dofile, runtime)
if not ok or type(theme) ~= "table" or (theme.mode ~= "dark" and theme.mode ~= "light") then
  return
end
vim.g.colors_name = nil
vim.o.background = theme.mode
vim.cmd("highlight clear")
vim.g.colors_name = "omarchy"
for group, highlights in pairs(theme.highlights or {}) do
  vim.api.nvim_set_hl(0, group, highlights)
end
