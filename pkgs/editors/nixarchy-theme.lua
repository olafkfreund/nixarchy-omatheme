if vim.g.loaded_nixarchy_theme_bridge then
  return
end
vim.g.loaded_nixarchy_theme_bridge = 1

local config = vim.env.XDG_CONFIG_HOME and vim.env.XDG_CONFIG_HOME ~= "" and vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")
local state = vim.env.XDG_STATE_HOME and vim.env.XDG_STATE_HOME ~= "" and vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
local runtime = config .. "/omarchy/runtime/neovim-theme.lua"
local spec = state .. "/omarchy/current/theme/neovim.lua"
local uv = vim.uv or vim.loop

local function read(path)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local contents = file:read("*a")
  file:close()
  return contents
end

local function mtime()
  local stat = uv.fs_stat(runtime)
  return stat and stat.mtime
end

local last_mtime = mtime()
local applied = read(runtime)
local applied_spec = read(spec)
local pending = false
local pending_native = false

local function apply(force_native)
  local contents = read(runtime)
  if not contents then
    return false
  end
  local ok, theme = pcall(dofile, runtime)
  if not ok or type(theme) ~= "table" or (theme.mode ~= "dark" and theme.mode ~= "light") then
    return false
  end

  local spec_contents = read(spec)
  local name
  local entries
  if spec_contents and (force_native or spec_contents ~= applied_spec) then
    local valid, parsed = pcall(dofile, spec)
    if valid and type(parsed) == "table" then
      entries = parsed
      for _, entry in pairs(entries) do
        if type(entry) == "table" and entry[1] == "LazyVim/LazyVim" and type(entry.opts) == "table" then
          name = entry.opts.colorscheme
          break
        end
      end
    end
  end

  vim.g.colors_name = nil
  vim.o.background = theme.mode
  if type(name) == "string" and name ~= "" then
    if package.loaded.lazy then
      pcall(function()
        require("lazy.core.plugin").load()
        local plugins = require("lazy.core.config").plugins
        for _, entry in pairs(entries) do
          if type(entry) == "table" and type(entry[1]) == "string" and entry[1] ~= "LazyVim/LazyVim" then
            local named, slugged, basename
            for _, plugin in pairs(plugins) do
              if entry.name and plugin.name == entry.name then
                named = plugin
                break
              elseif plugin[1] == entry[1] then
                slugged = plugin
              elseif plugin.name == entry[1]:match("([^/]+)$") then
                basename = plugin
              end
            end
            local plugin = named or slugged or basename
            if plugin and plugin._ and plugin._.installed then
              if not plugin._.loaded and type(plugin.dir) == "string" then
                pcall(require("lazy.core.util").walkmods, plugin.dir .. "/lua", function(modname)
                  package.loaded[modname] = nil
                  package.preload[modname] = nil
                end)
              end
              require("lazy.core.loader").reload(plugin)
            end
          end
        end
      end)
    end
    if pcall(vim.cmd.colorscheme, name) then
      applied, applied_spec, pending = contents, spec_contents, false
      return true
    end
  end
  if pcall(vim.cmd.colorscheme, "omarchy") and vim.g.colors_name == "omarchy" then
    applied, applied_spec, pending = contents, spec_contents, false
    return true
  end
  return false
end

local function reload(force_native)
  if vim.fn.mode() == "c" and not force_native then
    pending = true
    return
  end
  force_native = force_native or pending_native
  pending = not apply(force_native)
  pending_native = pending and force_native
end

vim.api.nvim_create_user_command("OmarchyThemeReload", function()
  reload(true)
end, {})

local group = vim.api.nvim_create_augroup("nixarchy_theme_bridge", { clear = true })
local function startup()
  local ok, normal = pcall(vim.api.nvim_get_hl, 0, { name = "Normal", link = false })
  -- shortcut: matches Neovim 0.10+ built-in Normal (NvimLightGrey2/NvimDarkGrey2); update if those change.
  local builtin = ok and ((normal.fg == 0xe0e2ea and normal.bg == 0x14161b)
    or (normal.fg == 0x14161b and normal.bg == 0xe0e2ea))
  -- LazyVim falls back to habamax when the configured colorscheme fails to load.
  local cfg_ok, cfg = pcall(require, "lazyvim.config")
  local fallback = vim.g.colors_name == "habamax" and cfg_ok and type(cfg) == "table" and cfg.colorscheme ~= "habamax"
  if fallback or (vim.g.colors_name == nil and ok and normal.ctermfg == nil and normal.ctermbg == nil
    and ((normal.fg == nil and normal.bg == nil) or builtin)) then
    reload(true)
  end
end
vim.api.nvim_create_autocmd("VimEnter", { group = group, callback = startup })
if vim.v.vim_did_enter == 1 then
  startup()
end

local timer = vim.fn.timer_start(500, function()
  local current = mtime()
  local moved = (current == nil) ~= (last_mtime == nil)
    or (current and last_mtime and (current.sec ~= last_mtime.sec or current.nsec ~= last_mtime.nsec))
  if moved then
    last_mtime = current
  end
  if not moved and not pending then
    return
  end
  local contents = read(runtime)
  if not contents then
    pending = current ~= nil
  elseif contents ~= applied or pending or pending_native then
    reload(false)
  else
    pending = false
  end
end, { ["repeat"] = -1 })
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    vim.fn.timer_stop(timer)
  end,
})
