#!/usr/bin/env bash
set -euo pipefail

: "${HYPRCHROMA_PACKAGE:?HYPRCHROMA_PACKAGE must point to a built hyprchroma package}"
: "${LAZY_NVIM:?LAZY_NVIM must point to a built lazy.nvim plugin}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

lib="$tmp/lib"
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_DATA_HOME="$tmp/data"
export XDG_STATE_HOME="$tmp/state"
export XDG_CACHE_HOME="$tmp/cache"
mkdir -p "$lib" "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

cp "$HYPRCHROMA_PACKAGE/lib/hyprchroma/hyprchroma-editors" "$lib/"
cp "$HYPRCHROMA_PACKAGE/lib/hyprchroma/hyprchroma-state" "$lib/"
python_bin=$(command -v python3)
sed -i "1c#!$python_bin" "$lib/hyprchroma-editors" "$lib/hyprchroma-state"

install -Dm644 "$HYPRCHROMA_PACKAGE/share/hyprchroma/editors/nixarchy-theme.lua" \
  "$XDG_DATA_HOME/nvim/site/plugin/nixarchy-theme.lua"
install -Dm644 "$HYPRCHROMA_PACKAGE/share/hyprchroma/editors/omarchy.lua" \
  "$XDG_DATA_HOME/nvim/site/colors/omarchy.lua"
install -Dm644 "$HYPRCHROMA_PACKAGE/share/hyprchroma/editors/nixarchy-theme.vim" \
  "$HOME/.vim/pack/nixarchy/start/nixarchy-theme/plugin/nixarchy-theme.vim"
install -Dm644 "$HYPRCHROMA_PACKAGE/share/hyprchroma/editors/omarchy.vim" \
  "$HOME/.vim/pack/nixarchy/start/nixarchy-theme/colors/omarchy.vim"

write_palette() {
  local mode="${1:-light}"
  local bg="${2:-#101820}"
  local fg="${3:-#f0f0e0}"
  local blue="${4:-#6090d0}"
  cat > "$lib/hyprchroma-palette" <<EOF
#!/bin/sh
cat <<'PALETTE'
mode	$mode
background	$bg
foreground	$fg
dark_background	#080c10
lighter_background	#304050
selection	#304050
accent	#40c0a0
muted	#809090
red	#e06060
green	#60c080
yellow	#d0b060
blue	$blue
magenta	#c080d0
bright_red	#ff7070
cyan	#70d0d0
PALETTE
EOF
  chmod 755 "$lib/hyprchroma-palette"
}

cat > "$lib/set-palette" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
lib=$(cd "$(dirname "$0")" && pwd)
mode="${1:-light}"
bg="${2:-#101820}"
fg="${3:-#f0f0e0}"
blue="${4:-#6090d0}"
cat > "$lib/hyprchroma-palette" <<PAL
#!/bin/sh
cat <<'PALETTE'
mode	$mode
background	$bg
foreground	$fg
dark_background	#080c10
lighter_background	#304050
selection	#304050
accent	#40c0a0
muted	#809090
red	#e06060
green	#60c080
yellow	#d0b060
blue	$blue
magenta	#c080d0
bright_red	#ff7070
cyan	#70d0d0
PALETTE
PAL
chmod 755 "$lib/hyprchroma-palette"
"$lib/hyprchroma-editors" >/dev/null
EOF
# The Nix build sandbox has no /usr/bin/env; pin the helper to this bash.
sed -i "1c#!$BASH" "$lib/set-palette"
chmod 755 "$lib/set-palette"

run_renderer() {
  "$lib/hyprchroma-editors" >/dev/null
}

# 1. Renderer output & idempotence checks
write_palette light "#101820" "#f0f0e0" "#6090d0"
run_renderer

test -f "$XDG_CONFIG_HOME/omarchy/runtime/neovim-theme.lua"
test -f "$XDG_CONFIG_HOME/omarchy/runtime/vim-theme.vim"
test -f "$XDG_STATE_HOME/hyprchroma/editors.json"
grep -Fq '["Normal"] = { fg = "#f0f0e0", bg = "#101820" }' "$XDG_CONFIG_HOME/omarchy/runtime/neovim-theme.lua"
grep -Fq '["@function"] = { link = "Function" }' "$XDG_CONFIG_HOME/omarchy/runtime/neovim-theme.lua"
grep -Fq 'unlet! g:colors_name' "$XDG_CONFIG_HOME/omarchy/runtime/vim-theme.vim"
grep -Fq "if !has('gui_running') && !&termguicolors" "$XDG_CONFIG_HOME/omarchy/runtime/vim-theme.vim"
grep -Fq 'set background=light' "$XDG_CONFIG_HOME/omarchy/runtime/vim-theme.vim"
grep -Fq "if has('termguicolors') && \$COLORTERM =~# 'truecolor\\|24bit' | set termguicolors | endif" "$XDG_CONFIG_HOME/omarchy/runtime/vim-theme.vim"
grep -Fq 'highlight Function guifg=#6090d0' "$XDG_CONFIG_HOME/omarchy/runtime/vim-theme.vim"
grep -Fq '"neovim": "generated"' "$XDG_STATE_HOME/hyprchroma/editors.json"

timeout 60 nvim --headless -u NONE \
  -c "lua local t=dofile('$XDG_CONFIG_HOME/omarchy/runtime/neovim-theme.lua'); for group, highlights in pairs(t.highlights) do vim.api.nvim_set_hl(0, group, highlights) end; local h=vim.api.nvim_get_hl(0, {name='Normal'}); assert(string.format('#%06x', h.fg) == '#f0f0e0')" \
  -c 'qa!'
timeout 60 vim -Nu NONE -n -es -c "set termguicolors" \
  -c "source $XDG_CONFIG_HOME/omarchy/runtime/vim-theme.vim" \
  -c "if execute('highlight Normal') !~ '#f0f0e0' | cquit | endif" \
  -c 'qa!'

before=$(sha256sum \
  "$XDG_CONFIG_HOME/omarchy/runtime/neovim-theme.lua" \
  "$XDG_CONFIG_HOME/omarchy/runtime/vim-theme.vim" \
  "$XDG_STATE_HOME/hyprchroma/editors.json")
run_renderer
test "$before" = "$(sha256sum \
  "$XDG_CONFIG_HOME/omarchy/runtime/neovim-theme.lua" \
  "$XDG_CONFIG_HOME/omarchy/runtime/vim-theme.vim" \
  "$XDG_STATE_HOME/hyprchroma/editors.json")"

# Setup mock plugins for LazyVim tests
mock1="$tmp/mocktheme.nvim"
mock2="$tmp/mocktheme2.nvim"
lazyvim_stub="$tmp/LazyVim"
mkdir -p "$mock1/lua/mocktheme" "$mock1/colors" "$mock2/lua/mocktheme2" "$mock2/colors" "$lazyvim_stub/lua/lazyvim"

cat > "$mock1/lua/mocktheme/init.lua" <<'EOF'
local M = { opts = { bg = "#111111" } }
function M.setup(opts)
  M.opts = vim.tbl_extend("force", M.opts, opts or {})
end
return M
EOF

cat > "$mock1/colors/mocktheme.lua" <<'EOF'
vim.cmd("highlight clear")
vim.g.colors_name = "mocktheme"
local bg = require("mocktheme").opts.bg or "#111111"
vim.api.nvim_set_hl(0, "Normal", { fg = "#ffffff", bg = bg })
EOF

cat > "$mock2/lua/mocktheme2/init.lua" <<'EOF'
local M = { opts = { bg = "#222222" } }
function M.setup(opts)
  M.opts = vim.tbl_extend("force", M.opts, opts or {})
end
return M
EOF

cat > "$mock2/colors/mocktheme2.lua" <<'EOF'
vim.cmd("highlight clear")
vim.g.colors_name = "mocktheme2"
local bg = require("mocktheme2").opts.bg or "#222222"
vim.api.nvim_set_hl(0, "Normal", { fg = "#ffffff", bg = bg })
EOF

cat > "$lazyvim_stub/lua/lazyvim/init.lua" <<'EOF'
return { setup = function() end }
EOF

mkdir -p "$XDG_CONFIG_HOME/nvim/lua/plugins" "$XDG_STATE_HOME/omarchy/current/theme"
ln -sf "$XDG_STATE_HOME/omarchy/current/theme/neovim.lua" "$XDG_CONFIG_HOME/nvim/lua/plugins/theme.lua"

cat > "$XDG_STATE_HOME/omarchy/current/theme/neovim.lua" <<EOF
return {
  { "mock/mocktheme.nvim", dir = "$mock1", opts = { bg = "#112233" } },
  { "LazyVim/LazyVim", dir = "$lazyvim_stub", opts = { colorscheme = "mocktheme" } },
}
EOF

cat > "$XDG_CONFIG_HOME/nvim/init.lua" <<EOF
vim.opt.rtp:prepend("$LAZY_NVIM")
require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { missing = false },
  rocks = { enabled = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
})
EOF

# 2. LazyVim load, same-plugin new opts, cross-plugin + mode, palette-only, fallback, failure recovery, manual pick kept
export TEST_LIB="$lib"
export TEST_TMP="$tmp"
export TEST_MOCK1="$mock1"
export TEST_MOCK2="$mock2"
export TEST_LAZYVIM="$lazyvim_stub"
export TEST_UID="$(id -u)"

cat > "$tmp/lazy_cases.lua" <<'EOF'
local function fail(msg)
  io.stderr:write("FAIL: " .. msg .. "\n")
  vim.cmd("cq")
end

local function normal_bg()
  local h = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  return h.bg and string.format("#%06x", h.bg) or ""
end

local function hl_fg(name)
  local h = vim.api.nvim_get_hl(0, { name = name, link = false })
  return h.fg and string.format("#%06x", h.fg) or ""
end

local function write_file(path, text)
  local f = assert(io.open(path, "wb"))
  f:write(text)
  f:close()
end

local function set_palette(mode, bg, fg, blue)
  vim.fn.system({ vim.env.TEST_LIB .. "/set-palette", mode, bg, fg or "#f0f0e0", blue or "#6090d0" })
  if vim.v.shell_error ~= 0 then
    fail("set-palette failed")
  end
end

local spec_path = vim.env.XDG_STATE_HOME .. "/omarchy/current/theme/neovim.lua"
local runtime_path = vim.env.XDG_CONFIG_HOME .. "/omarchy/runtime/neovim-theme.lua"
local mock1 = vim.env.TEST_MOCK1
local mock2 = vim.env.TEST_MOCK2
local lv = vim.env.TEST_LAZYVIM

-- Case A: LazyVim load
if vim.fn.exists(":OmarchyThemeReload") ~= 2 then
  fail(":OmarchyThemeReload missing under LazyVim")
end
if vim.g.colors_name ~= "mocktheme" then
  fail("expected startup colorscheme mocktheme, got " .. tostring(vim.g.colors_name))
end
if normal_bg() ~= "#112233" then
  fail("expected startup Normal.bg #112233, got " .. normal_bg())
end
if vim.o.background ~= "light" then
  fail("expected startup background light, got " .. vim.o.background)
end

-- Case B: Same plugin, new opts
write_file(spec_path, string.format([[
return {
  { "mock/mocktheme.nvim", dir = %q, opts = { bg = "#445566" } },
  { "LazyVim/LazyVim", dir = %q, opts = { colorscheme = "mocktheme" } },
}
]], mock1, lv))
set_palette("light", "#101821", "#f0f0e0", "#6090d0")
if not vim.wait(2000, function() return normal_bg() == "#445566" end, 50) then
  fail("same plugin new opts did not update Normal.bg to #445566 (got " .. normal_bg() .. ")")
end
if vim.g.colors_name ~= "mocktheme" then
  fail("expected mocktheme after opts change, got " .. tostring(vim.g.colors_name))
end

-- Case C: Cross-plugin and mode
write_file(spec_path, string.format([[
return {
  { "mock/mocktheme2.nvim", dir = %q, opts = { bg = "#223344" } },
  { "LazyVim/LazyVim", dir = %q, opts = { colorscheme = "mocktheme2" } },
}
]], mock2, lv))
set_palette("dark", "#0a0b0c", "#f0f0e0", "#6090d0")
if not vim.wait(2000, function() return vim.g.colors_name == "mocktheme2" and normal_bg() == "#223344" and vim.o.background == "dark" end, 50) then
  fail("cross-plugin switch failed: colors_name=" .. tostring(vim.g.colors_name) .. " bg=" .. normal_bg() .. " mode=" .. vim.o.background)
end

-- Case D: Palette-only -> omarchy
set_palette("dark", "#331122", "#f0f0e0", "#5588cc")
if not vim.wait(2000, function() return vim.g.colors_name == "omarchy" and normal_bg() == "#331122" end, 50) then
  fail("palette-only switch did not apply omarchy #331122: colors_name=" .. tostring(vim.g.colors_name) .. " bg=" .. normal_bg())
end

-- Case E1: Fallback when neovim.lua names a missing plugin
vim.cmd("messages clear")
write_file(spec_path, string.format([[
return {
  { "missing/nonexistent-theme.nvim", opts = {} },
  { "LazyVim/LazyVim", dir = %q, opts = { colorscheme = "nonexistent-theme" } },
}
]], lv))
set_palette("dark", "#123456", "#f0f0e0", "#336699")
if not vim.wait(2000, function() return vim.g.colors_name == "omarchy" and normal_bg() == "#123456" end, 50) then
  fail("missing-plugin fallback failed: colors_name=" .. tostring(vim.g.colors_name) .. " bg=" .. normal_bg())
end
if hl_fg("@function") ~= "#336699" then
  fail("expected @function fg #336699, got " .. hl_fg("@function"))
end
local msgs = vim.fn.execute("messages")
if msgs:match("E%d+") then
  fail("unexpected error in :messages during missing-plugin fallback: " .. msgs)
end

-- Case E2: Fallback when neovim.lua does not exist
vim.cmd.colorscheme("default")
os.remove(vim.env.XDG_CONFIG_HOME .. "/nvim/lua/plugins/theme.lua")
os.remove(spec_path)
set_palette("light", "#654321", "#101010", "#114477")
if not vim.wait(2000, function() return vim.g.colors_name == "omarchy" and normal_bg() == "#654321" and vim.o.background == "light" end, 50) then
  fail("no-neovim.lua fallback failed: colors_name=" .. tostring(vim.g.colors_name) .. " bg=" .. normal_bg())
end
if hl_fg("@function") ~= "#114477" then
  fail("expected @function fg #114477, got " .. hl_fg("@function"))
end
msgs = vim.fn.execute("messages")
if msgs:match("E%d+") then
  fail("unexpected error in :messages during no-neovim.lua fallback: " .. msgs)
end

-- Case F: Failure recovery (stage at mode 000 in same dir, mv -f into place, wait one tick, chmod 644, wait)
if vim.env.TEST_UID == "0" then
  io.stdout:write("SKIP failure recovery chmod 000 check when running as root\n")
else
  local staged = runtime_path .. ".staged"
  local current_text = assert(io.open(runtime_path, "rb")):read("*a")
  local next_text = current_text:gsub("#654321", "#abcdef")
  write_file(staged, next_text)
  vim.fn.system({ "chmod", "000", staged })
  vim.fn.system({ "mv", "-f", staged, runtime_path })
  vim.wait(700, function() return false end, 100)
  if normal_bg() == "#abcdef" then
    fail("unreadable runtime file should not have applied yet")
  end
  vim.fn.system({ "chmod", "644", runtime_path })
  if not vim.wait(2000, function() return normal_bg() == "#abcdef" end, 50) then
    fail("failure recovery did not apply #abcdef after chmod 644 (got " .. normal_bg() .. ")")
  end
end

-- Case G: Manual pick kept across identical renderer rerun
vim.cmd.colorscheme("default")
if vim.g.colors_name ~= "default" then
  fail("failed to set manual colorscheme default")
end
-- Ensure runtime matches current palette first so rerun produces identical content
set_palette("light", "#777777", "#101010", "#114477")
if not vim.wait(2000, function() return vim.g.colors_name == "omarchy" and normal_bg() == "#777777" end, 50) then
  fail("prep for manual pick failed")
end
vim.cmd.colorscheme("default")
set_palette("light", "#777777", "#101010", "#114477")
vim.wait(700, function() return false end, 100)
if vim.g.colors_name ~= "default" then
  fail("manual colorscheme default was overwritten by identical palette rerun: " .. tostring(vim.g.colors_name))
end

vim.cmd("qa!")
EOF

timeout 60 nvim --headless -c "autocmd VimEnter * ++once luafile $tmp/lazy_cases.lua"

# 3. Startup precedence cases
rm -rf "$XDG_CONFIG_HOME/nvim"
mkdir -p "$XDG_CONFIG_HOME/nvim"
write_palette dark "#182838" "#f0f0e0" "#6090d0"
run_renderer

# 3a. colorscheme set in init.lua -> kept
cat > "$XDG_CONFIG_HOME/nvim/init.lua" <<'EOF'
vim.cmd.colorscheme("default")
EOF
cat > "$tmp/startup_cs.lua" <<'EOF'
assert(vim.g.colors_name == "default", "expected default, got " .. tostring(vim.g.colors_name))
vim.cmd("qa!")
EOF
timeout 60 nvim --headless -c "autocmd VimEnter * ++once luafile $tmp/startup_cs.lua"

# 3b. Normal highlight set in init.lua -> kept (colors_name remains nil, Normal.bg kept)
cat > "$XDG_CONFIG_HOME/nvim/init.lua" <<'EOF'
vim.api.nvim_set_hl(0, "Normal", { fg = "#eeeeee", bg = "#123123" })
EOF
cat > "$tmp/startup_hl.lua" <<'EOF'
local h = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
assert(vim.g.colors_name == nil, "expected nil colors_name, got " .. tostring(vim.g.colors_name))
assert(string.format("#%06x", h.bg) == "#123123", "expected #123123")
vim.cmd("qa!")
EOF
timeout 60 nvim --headless -c "autocmd VimEnter * ++once luafile $tmp/startup_hl.lua"

# 3b2. LazyVim's habamax fallback (configured colorscheme failed) -> omarchy at startup
cat > "$XDG_CONFIG_HOME/nvim/init.lua" <<'EOF'
package.preload["lazyvim.config"] = function() return { colorscheme = "missingtheme" } end
vim.cmd.colorscheme("habamax")
EOF
cat > "$tmp/startup_habamax.lua" <<'EOF'
assert(vim.g.colors_name == "omarchy", "expected omarchy over habamax, got " .. tostring(vim.g.colors_name))
vim.cmd("qa!")
EOF
timeout 60 nvim --headless -c "autocmd VimEnter * ++once luafile $tmp/startup_habamax.lua"

# 3c. Empty init.lua -> desktop theme applied, and plain Neovim (no lazy.nvim) follows live switch
: > "$XDG_CONFIG_HOME/nvim/init.lua"
cat > "$tmp/plain_nvim.lua" <<'EOF'
local function normal_bg()
  local h = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  return h.bg and string.format("#%06x", h.bg) or ""
end
assert(vim.g.colors_name == "omarchy", "expected omarchy at startup, got " .. tostring(vim.g.colors_name))
assert(normal_bg() == "#182838", "expected #182838 at startup, got " .. normal_bg())
vim.fn.system({ vim.env.TEST_LIB .. "/set-palette", "light", "#fedcba", "#101010", "#6090d0" })
local ok = vim.wait(2000, function()
  return normal_bg() == "#fedcba" and vim.o.background == "light"
end, 50)
if not ok then
  io.stderr:write("plain Neovim live switch failed: bg=" .. normal_bg() .. "\n")
  vim.cmd("cq")
end
vim.cmd("qa!")
EOF
timeout 60 nvim --headless -c "autocmd VimEnter * ++once luafile $tmp/plain_nvim.lua"

# 4. Vim: startup applies omarchy, two renderer writes within one second both reach the session via timer, :OmarchyThemeReload exists
write_palette light "#101820" "#f0f0e0" "#6090d0"
run_renderer

cat > "$tmp/vimrc" <<'EOF'
set nocompatible
EOF

cat > "$tmp/t.vim" <<EOF
let s:out = '$tmp/vim-result.txt'
let s:log = []
call add(s:log, 'start:' . get(g:, 'colors_name', 'NONE') . ':' . &background . ':' . synIDattr(synIDtrans(hlID('Normal')), 'bg', 'gui'))
call add(s:log, 'cmd:' . exists(':OmarchyThemeReload'))

call system('$lib/set-palette dark "#203040" "#f0f0e0" "#6090d0"')
sleep 700m
call add(s:log, 'first:' . &background . ':' . synIDattr(synIDtrans(hlID('Normal')), 'bg', 'gui'))

call system('$lib/set-palette light "#304050" "#f0f0e0" "#6090d0"')
call system('touch -r $XDG_CONFIG_HOME/omarchy/runtime/vim-theme.vim $tmp/vim-mtime')
sleep 700m
call add(s:log, 'mid:' . &background . ':' . synIDattr(synIDtrans(hlID('Normal')), 'bg', 'gui'))
call system('$lib/set-palette dark "#405060" "#f0f0e0" "#6090d0"')
" Same mtime as the previous write, so an mtime-only watcher would miss it.
call system('touch -r $tmp/vim-mtime $XDG_CONFIG_HOME/omarchy/runtime/vim-theme.vim')
sleep 700m
call add(s:log, 'second:' . &background . ':' . synIDattr(synIDtrans(hlID('Normal')), 'bg', 'gui'))

highlight clear
unlet! g:colors_name
OmarchyThemeReload
call add(s:log, 'reload:' . get(g:, 'colors_name', 'NONE') . ':' . synIDattr(synIDtrans(hlID('Normal')), 'bg', 'gui'))

call writefile(s:log, s:out)
qa!
EOF

COLORTERM=truecolor TERM=xterm-256color timeout 60 script -qec \
  "vim -X -u $tmp/vimrc -i NONE -n -c 'autocmd VimEnter * ++once source $tmp/t.vim'" \
  /dev/null </dev/null >/dev/null

grep -Fq 'start:omarchy:light:#101820' "$tmp/vim-result.txt"
grep -Fq 'cmd:2' "$tmp/vim-result.txt"
grep -Fq 'first:dark:#203040' "$tmp/vim-result.txt"
grep -Fq 'mid:light:#304050' "$tmp/vim-result.txt"
grep -Fq 'second:dark:#405060' "$tmp/vim-result.txt"
grep -Fq 'reload:omarchy:#405060' "$tmp/vim-result.txt"

echo "editor runtime test passed"

# 4b. Vim: a user colour set only for the terminal, through a link, keeps omarchy off at startup
cat > "$tmp/vimrc-user" <<'EOF'
set nocompatible
highlight MyBg ctermbg=4
highlight! link Normal MyBg
EOF
cat > "$tmp/t-user.vim" <<EOF
call writefile([get(g:, 'colors_name', 'NONE')], '$tmp/vim-user.txt')
qa!
EOF
COLORTERM=truecolor TERM=xterm-256color timeout 60 script -qec \
  "vim -X -u $tmp/vimrc-user -i NONE -n -c 'autocmd VimEnter * ++once source $tmp/t-user.vim'" \
  /dev/null </dev/null >/dev/null
grep -Fxq 'NONE' "$tmp/vim-user.txt" || { echo "FAIL: Vim startup overrode user cterm colours: $(cat "$tmp/vim-user.txt")"; exit 1; }
