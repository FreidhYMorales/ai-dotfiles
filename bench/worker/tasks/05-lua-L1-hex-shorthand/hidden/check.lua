-- Hidden harness for 05-lua-L1-hex-shorthand (cwd = repo root).
vim = { o = { background = "dark" } }
package.path = "dotfiles/nvim/.config/nvim/lua/?.lua;" .. package.path
local u = require("Deadlock.my-theme.utils")

local failures = 0
local function eq(label, want, fn, ...)
  local ok, got = pcall(fn, ...)
  if not ok or got ~= want then
    print(("FAIL %s: got %s, want %s"):format(label, tostring(got), tostring(want)))
    failures = failures + 1
  end
end
local function errors(label, ...)
  if pcall(u.mix, ...) then
    print("FAIL " .. label .. ": no error")
    failures = failures + 1
  end
end

eq("6-digit still works", "#800080", u.mix, "#ff0000", "#0000ff", 0.5)
eq("shorthand fg and bg", "#808080", u.mix, "#fff", "#000", 0.5)
eq("shorthand expands each digit", "#AABBCC", u.mix, "#abc", "#000000", 1)
eq("shorthand upper case", "#FF0000", u.mix, "#F00", "#00F", 1)
eq("shorthand as background", "#FFAA00", u.mix, "#000000", "#fa0", 0)
eq("none passthrough", "none", u.mix, "none", "#fff", 0.5)
eq("shade with shorthand base", "#FFFFFF", u.shade, "#000", 0, "#fff")
vim.o.background = "light"
eq("shade light default base", "#FFFFFF", u.shade, "#fff", 1)
errors("two digits", "#ff", "#000", 0.5)
errors("four digits", "#ffff", "#000", 0.5)
errors("five digits", "#fffff", "#000", 0.5)
errors("no hash", "fff", "#000", 0.5)
errors("non-hex shorthand", "#ggg", "#000", 0.5)
errors("bad background", "#fff", "#12", 0.5)

if failures > 0 then
  os.exit(1)
end
print("ok")
