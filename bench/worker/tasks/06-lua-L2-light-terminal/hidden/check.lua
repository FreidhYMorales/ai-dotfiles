-- Hidden harness for 06-lua-L2-light-terminal (cwd = repo root).
local kitty_output = ""
vim = {
  o = { background = "dark" },
  v = { shell_error = 0 },
  g = {},
  fn = {
    expand = function(s) return s end,
    system = function() return kitty_output end,
    stdpath = function() return "/nonexistent" end,
  },
  uv = { fs_stat = function() return nil end },
}
vim.loop = vim.uv
package.path = "dotfiles/nvim/.config/nvim/lua/?.lua;" .. package.path

local failures = 0
local function eq(label, want, got)
  if got ~= want then
    print(("FAIL %s: got %s, want %s"):format(label, tostring(got), tostring(want)))
    failures = failures + 1
  end
end

local ok, utils = pcall(require, "Deadlock.my-theme.utils")
if not ok then
  print("FAIL require utils: " .. tostring(utils))
  os.exit(1)
end
if type(utils.lighten) ~= "function" then
  print("FAIL utils.lighten is not a function")
  os.exit(1)
end
local function lighten(...)
  local ok2, res = pcall(utils.lighten, ...)
  return ok2 and res or ("error: " .. tostring(res))
end
eq("lighten adds", "#1a1a1a", lighten("#101010", 10))
eq("lighten clamps at 255", "#ffffff", lighten("#f0f0f0", 30))
eq("negative darkens and clamps at 0", "#000000", lighten("#050505", -10))
eq("per channel", "#70ef00", lighten("#80FF00", -16))
eq("lowercase output", "#abcdef", lighten("#ABCDEF", 0))

local ok3, terminal = pcall(require, "Deadlock.my-theme.terminal")
if not ok3 then
  print("FAIL require terminal: " .. tostring(terminal))
  os.exit(1)
end

-- palette BG: load() with kitty IPC reporting background BG.
local function palette(bg)
  local lines = { "foreground\t#c0c0c0", "background\t" .. bg, "cursor\t#ffffff" }
  for i = 0, 15 do
    lines[#lines + 1] = ("color%d\t#%02x%02x%02x"):format(i, i * 10, i * 11, i * 12)
  end
  kitty_output = table.concat(lines, "\n") .. "\n"
  local ok4, p = pcall(terminal.load)
  if not ok4 or type(p) ~= "table" then
    print("FAIL load() with background " .. bg .. ": " .. tostring(p))
    failures = failures + 1
    return {}
  end
  return p
end

local keys = { "sidebarBackground", "popupBackground", "floatingWindowBackground",
  "menuOptionBackground", "windowBorder", "focusedBorder", "emphasizedBorder" }
local amounts = { 10, 10, 25, 37, 25, 37, 50 }

-- expect BG SIGN IS_DARK: chrome = BG +/- the usual amounts.
local function expect(bg, sign, is_dark)
  local p = palette(bg)
  local v = tonumber(bg:sub(2, 3), 16)
  for i, k in ipairs(keys) do
    local c = math.max(0, math.min(255, v + sign * amounts[i]))
    eq(bg .. " " .. k, ("#%02x%02x%02x"):format(c, c, c), p[k])
  end
  eq(bg .. " is_dark", is_dark, p.is_dark)
  eq(bg .. " editorBackground", bg, p.editorBackground)
  eq(bg .. " mainText", "#c0c0c0", p.mainText)
  eq(bg .. " is_transparent", false, p.is_transparent)
end

expect("#101010", 1, true)
expect("#f0f0f0", -1, false)
expect("#808080", -1, false) -- brightness 128: light
expect("#7f7f7f", 1, true) -- brightness 127: dark
expect("#fafafa", -1, false)

-- Colored backgrounds use the weighted brightness, not the average.
local green = palette("#00e000") -- weighted 131 (light), average 75
eq("green is light", false, green.is_dark)
eq("green sidebar", "#00d600", green.sidebarBackground)
local magenta = palette("#ff00ff") -- weighted 105 (dark), average 170
eq("magenta is dark", true, magenta.is_dark)
eq("magenta sidebar", "#ff0aff", magenta.sidebarBackground)

if failures > 0 then
  os.exit(1)
end
print("ok")
