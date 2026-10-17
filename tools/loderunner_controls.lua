-- 《警察抓小偷》方向键控制层（进入游戏时由 play_loderunner.lua 调用 lr_controls_start()）
--
-- 游戏在 $6A18 读键（LDX $C000），字母键存进 $9E/$9F，之后不再按键就一直按这个方向走（锁存式），
-- 空格这类不认识的键等于站住；挖洞后游戏把 $9E/$9F 写成 $FF（站住）。
-- 电脑方向键在模拟键盘上是 Ctrl-H/U/K/J（$88/$95/$8B/$8A），在游戏里分别是减速、加速、键盘模式、
-- 摇杆模式，按下键会切到摇杆模式而失控。这里在 $6A18 读键时屏蔽这四个码（按住 Ctrl 时放行），
-- 改为每帧看电脑方向键：按住时注入 I/J/K/L，松开时注入空格站住；Z/X 注入 U/O 挖洞。
-- 只在 $6A18 这一处注入，标题画面、演示、关卡开始前的"按任意键"都不受影响。

local m = manager.machine
local cpu = m.devices[":maincpu"]
local space = cpu.spaces["program"]
local inp = m.input

local function codes(...)
  local t = {}
  for _, tok in ipairs({ ... }) do t[#t + 1] = inp:code_from_token(tok) end
  return t
end
local KEY = {
  up = codes("KEYCODE_UP"), down = codes("KEYCODE_DOWN"),
  left = codes("KEYCODE_LEFT"), right = codes("KEYCODE_RIGHT"),
  dig_left = codes("KEYCODE_Z"), dig_right = codes("KEYCODE_X"),
  ctrl = codes("KEYCODE_LCONTROL", "KEYCODE_RCONTROL"),
}
local GAME_KEY = { up = 0xC9, left = 0xCA, down = 0xCB, right = 0xCC, dig_left = 0xD5, dig_right = 0xCF }
local STOP = 0xA0
local DIRS = { "up", "down", "left", "right" }
local IS_DIR = { [0xC9] = true, [0xCA] = true, [0xCB] = true, [0xCC] = true }
local MASKED = { [0x88] = true, [0x95] = true, [0x8B] = true, [0x8A] = true }
local READ_KEY = 0x6A18

local held = function(name)
  for _, c in ipairs(KEY[name]) do if inp:code_pressed(c) then return true end end
  return false
end

local enabled = false
local dig = nil          -- 待注入的挖洞键
local dir = nil          -- 待注入的方向键或空格
local order, was = {}, {}  -- 方向键按下的先后，同时按两个时后按的那个算数
local dig_was = {}

LR_KBD_TAP = space:install_read_tap(0xC000, 0xC000, "loderunner_kbd", function(offset, data, mask)
  if not enabled or cpu.state["PC"].value ~= READ_KEY then return data end
  local k = dig or dir
  if k then
    if dig then dig = nil else dir = nil end
    return k
  end
  if MASKED[data & 0xFF] and not held("ctrl") then return data & 0x7F end
  return data
end)

LR_CTRL_FRAME = emu.register_frame_done(function()
  if not enabled then return end
  for _, d in ipairs(DIRS) do
    local h = held(d)
    if h and not was[d] then order[#order + 1] = d end
    if not h then
      for i = #order, 1, -1 do if order[i] == d then table.remove(order, i) end end
    end
    was[d] = h
  end
  for _, d in ipairs({ "dig_left", "dig_right" }) do
    local h = held(d)
    if h and not dig_was[d] then dig = GAME_KEY[d] end
    dig_was[d] = h
  end
  -- 和游戏当前的方向比：按住方向键而人没在这么走（刚挖完洞、刚开局）就补发；松开了而人还在走就发空格
  local cur = space:read_u8(0x9E)
  if #order > 0 then
    local want = GAME_KEY[order[#order]]
    dir = cur ~= want and want or nil
  else
    dir = IS_DIR[cur] and STOP or nil
  end
end)

function lr_controls_start()
  enabled = true
  print("Lode Runner controls: 方向键移动，Z/X（或 U/O）向左/向右挖洞")
end

-- 测试钩子：LR_FAKE_KEYS="t0:keys;t1:keys;..."（游戏开始后的秒数:逗号分隔的动作名），用于无界面验证
local fake = os.getenv("LR_FAKE_KEYS")
if fake then
  local plan, t0 = {}, nil
  for t, ks in fake:gmatch("([%d%.]+):([%w_,]*)") do plan[#plan + 1] = { tonumber(t), ks } end
  held = function(name)
    t0 = t0 or m.time:as_double()
    local t, active = m.time:as_double() - t0, ""
    for _, p in ipairs(plan) do if t >= p[1] then active = p[2] end end
    return ("," .. active .. ","):find("," .. name .. ",", 1, true) ~= nil
  end
end
