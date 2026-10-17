-- Hidden harness for 07-lua-L3-mtp-unmount (cwd = repo root). Stubs the yazi
-- API with a fake filesystem/command layer and drives M:entry.
local PLUGIN = "dotfiles/yazi/.config/yazi/plugins/simple-mtp.yazi/main.lua"
local UID = "4242"
local BASE = "/run/user/" .. UID .. "/mtp"

local state -- per scenario: mounts (nil = dir missing), calls, notes, pick
local function reset(mounts, pick)
  state = { mounts = mounts, calls = {}, notes = {}, pick = pick, emits = {} }
end

local function ls_result(path)
  if path == BASE and state.mounts then
    return table.concat(state.mounts, "\n") .. (#state.mounts > 0 and "\n" or ""), "", true, 0
  end
  return "", "ls: cannot access '" .. path .. "': No such file or directory\n", false, 2
end

local function fake_run(cmd, args)
  state.calls[#state.calls + 1] = { cmd = cmd, args = args }
  if cmd == "ls" then
    local path = args[#args]
    return ls_result(path)
  elseif cmd == "simple-mtpfs" and args[1] == "--list-devices" then
    return "1: Google Pixel 7 (MTP)\n2: Kindle\n", "", true, 0
  end
  return "", "", true, 0
end

-- Url stub
local UrlMT = {}
UrlMT.__index = UrlMT
UrlMT.__tostring = function(u) return u.path end
function Url(p)
  p = tostring(p)
  return setmetatable({ path = p, name = p:match("([^/]+)/*$"), parent = nil }, UrlMT)
end
function UrlMT:join(n) return Url(self.path .. "/" .. tostring(n)) end

-- Command stub
local function builder(cmd)
  local b = { cmd = cmd, argv = {} }
  local function chain(f) return function(self, ...) f(self, ...); return self end end
  b.arg = chain(function(self, a)
    if type(a) == "table" then
      for _, x in ipairs(a) do self.argv[#self.argv + 1] = tostring(x) end
    else
      self.argv[#self.argv + 1] = tostring(a)
    end
  end)
  b.args = chain(function(self, a) for _, x in ipairs(a) do self.argv[#self.argv + 1] = tostring(x) end end)
  for _, m in ipairs({ "stdout", "stderr", "stdin", "cwd", "env" }) do b[m] = chain(function() end) end
  local function output(self)
    local out, err, ok, code = fake_run(self.cmd, self.argv)
    return { stdout = out, stderr = err, status = { success = ok, code = code } }
  end
  b.output = function(self) return output(self), nil end
  b.spawn = function(self)
    local o = output(self)
    return { wait_with_output = function() return o, nil end, wait = function() return o.status end }, nil
  end
  return b
end
Command = setmetatable({ PIPED = 1, NULL = 0, INHERIT = 2 }, { __call = function(_, cmd) return builder(cmd) end })

-- fs stub (in case the fix lists the dir directly)
fs = {
  read_dir = function(url)
    if tostring(url) ~= BASE or not state.mounts then
      return nil, "No such file or directory"
    end
    local files = {}
    for _, n in ipairs(state.mounts) do
      local u = Url(BASE .. "/" .. n)
      files[#files + 1] = { url = u, name = n, cha = { is_dir = true } }
    end
    return files
  end,
  cha = function(url)
    if tostring(url) == BASE and state.mounts then return { is_dir = true } end
    return nil, "No such file or directory"
  end,
}

ya = {
  uid = function() return tonumber(UID) end,
  notify = function(t) state.notes[#state.notes + 1] = t end,
  which = function() return state.pick end,
  emit = function(name, args) state.emits[#state.emits + 1] = { name = name, args = args } end,
  sync = function(f) return f end,
  dbg = function() end,
  err = function() end,
}

local chunk, lerr = loadfile(PLUGIN)
if not chunk then
  print("FAIL load: " .. tostring(lerr))
  os.exit(1)
end
local M = chunk()

local failures = 0
local function check(label, cond, detail)
  if not cond then
    print("FAIL " .. label .. (detail and (": " .. detail) or ""))
    failures = failures + 1
  end
end
local function called(cmd)
  for _, c in ipairs(state.calls) do
    if c.cmd == cmd then return c end
  end
end
local function notes()
  local t = {}
  for _, n in ipairs(state.notes) do t[#t + 1] = (n.level or "info") .. ":" .. tostring(n.content) end
  return table.concat(t, " | ")
end
local function noted(level, text)
  for _, n in ipairs(state.notes) do
    if (n.level or "info") == level and tostring(n.content):find(text, 1, true) then return true end
  end
  return false
end
-- entry ACTION: works with both entry(self, job) and the older entry(self, _, args).
local function entry(action)
  local ok, err = pcall(M.entry, M, { args = { action } }, { action })
  check("entry " .. action .. " runs", ok, tostring(err))
end

-- 1. Nothing ever mounted: the mount dir does not exist.
reset(nil, 1)
entry("unmount")
check("missing dir: warns nothing is mounted", noted("warn", "No hay dispositivos MTP montados"), notes())
check("missing dir: no fusermount", not called("fusermount"))
check("missing dir: no error notification", not noted("error", ""), notes())

-- 2. Mount dir exists but is empty.
reset({}, 1)
entry("unmount")
check("empty dir: warns nothing is mounted", noted("warn", "No hay dispositivos MTP montados"), notes())
check("empty dir: no fusermount", not called("fusermount"))

-- 3. Two devices mounted, the user picks the second.
reset({ "device1", "device3" }, 2)
entry("unmount")
local fu = called("fusermount")
check("two mounts: fusermount called", fu ~= nil, notes())
check("two mounts: unmounts the picked one", fu and fu.args[#fu.args] == BASE .. "/device3",
  fu and table.concat(fu.args, " "))
check("two mounts: reports success", noted("info", "Desmontado: device3"), notes())

-- 4. One device mounted: no picker, unmounts it.
reset({ "device1" }, nil)
entry("unmount")
fu = called("fusermount")
check("one mount: unmounts it", fu and fu.args[#fu.args] == BASE .. "/device1", notes())

-- 5. Mount still works.
reset(nil, 2)
entry("mount")
local mt
for _, c in ipairs(state.calls) do
  if c.cmd == "simple-mtpfs" and c.args[1] == "--device" then mt = c end
end
check("mount: mounts the picked device", mt and mt.args[2] == "2" and mt.args[3] == BASE .. "/device2", notes())
check("mount: reports success", noted("info", "Kindle"), notes())

if failures > 0 then
  os.exit(1)
end
print("ok")
