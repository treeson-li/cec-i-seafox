-- 《警察抓小偷》方向键控制层（进入游戏时由 play_loderunner.lua 调用 lr_controls_start()）
--
-- 游戏在 $6A18 读键（LDX $C000），字母键存进 $9E/$9F，之后不再按键就一直按这个方向走（锁存式），
-- 空格这类不认识的键等于站住；挖洞后游戏把 $9E/$9F 写成 $FF（站住）。
-- 电脑方向键在模拟键盘上是 Ctrl-H/U/K/J（$88/$95/$8B/$8A），在游戏里分别是减速、加速、键盘模式、
-- 摇杆模式，按下键会切到摇杆模式而失控。这里在 $6A18 读键时屏蔽这四个码（按住 Ctrl 时放行），
-- 改为每帧看电脑方向键：按住时注入 I/J/K/L，松开时注入空格站住；Z/X 注入 U/O 挖洞。
-- 只在 $6A18 这一处注入，标题画面、演示、关卡开始前的"按任意键"都不受影响（选关除外，见下）。
--
-- 关卡流程：$609F 装入第 $96 关（从 0 起，$A6 是显示的关号）并揭幕 -> $60BC 调 $8700 闪着人等按键 ->
-- $60E4 起每节拍循环。死了 $613F 扣命、播动画，还有命就 JMP $609F 重装 $96；过关 $611A 给 $96/$A6 加 1。
-- 开局：标题画面按键后 $6201 写 $96=0、$A6=1、$9D=1（$9D 为 0 时这局不进高分榜）。
--
-- 起始关卡（LR_START_LEVEL，play_loderunner.sh 的数字参数）：在开局写 $96/$A6 时换成这一关，
-- 每局都从这关开始，死了重来还是这关，过关照常进下一关。
-- 运行中选关：PgUp/PgDn（Mac 上 Fn+↑/↓）调目标关号 ±1，按住 Shift ±10，左上角一直显示到换好。停手 0.4 秒后
-- 写进 $96/$A6，等游戏下一次装关（死了、过关都会装）；如果正在玩或在开场等按键，就把 $60E4 的 JSR $64BD
-- 临时改成 JMP $609F 立即重装（等按键时先替人按一下键让循环走到这里），装关时改回来。不死人、不扣命、分数不变。
-- 从第 1 关以外开始或选过关，按原版的规矩把 $9D 清零，这一局不进高分榜（原版的 Ctrl-^ 跳关、编辑器试玩也这样）。

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
  level_up = codes("KEYCODE_PGUP"), level_down = codes("KEYCODE_PGDN"),
  shift = codes("KEYCODE_LSHIFT", "KEYCODE_RSHIFT"),
}
local GAME_KEY = { up = 0xC9, left = 0xCA, down = 0xCB, right = 0xCC, dig_left = 0xD5, dig_right = 0xCF }
local STOP = 0xA0
local DIRS = { "up", "down", "left", "right" }
local IS_DIR = { [0xC9] = true, [0xCA] = true, [0xCB] = true, [0xCC] = true }
local MASKED = { [0x88] = true, [0x95] = true, [0x8B] = true, [0x8A] = true }
local READ_KEY = 0x6A18
local WAIT_KEY = { [0x8713] = true, [0x872B] = true }  -- $8700 里读键的两处；编辑器也用这个例程
local WAIT_ARG, START_BLINK = 0x8745, 9                  -- 开场时 $8700 的参数 A=9
local LEVEL, LEVEL_SHOWN, MODE, HISCORE_OK = 0x96, 0xA6, 0xA7, 0x9D  -- $A7=2 正在玩（1 是演示）
local LOOP_TOP, LOAD_LEVEL, DO_LOAD = 0x60E4, 0x609F, 0x6238
local LOOP_CODE = { 0x20, 0xBD, 0x64 }                   -- $60E4: JSR $64BD
-- $88A2 揭幕：$A5 非 0 时先在 $88B6 收圈（半径 $6D 从 $AA 减到 1），再在 $88CB 开圈（1 加到 $AA），
-- 每圈把第二页（$4000，新关已画好）的一圈拷到第一页
local IRIS, IRIS_CLOSE, IRIS_OPEN, IRIS_SHOWN, IRIS_R, IRIS_MAX = 0x88A2, 0x88B6, 0x88CB, 0xA5, 0x6D, 0xAA
local GAME_START = 0x6203                                -- $6201 LDX #0 / STX $96 / INX / STX $A6 / STX $9D
local LEVELS = 150

local held = function(name)
  for _, c in ipairs(KEY[name]) do if inp:code_pressed(c) then return true end end
  return false
end

local enabled = false
local dig = nil          -- 待注入的挖洞键
local dir = nil          -- 待注入的方向键或空格
local order, was = {}, {}  -- 方向键按下的先后，同时按两个时后按的那个算数
local dig_was = {}
local target, changed_at, show_until = nil, 0, 0  -- 选关的目标关号（1 起）、最后一次按键时间、显示到何时
local level_was = {}
local reload = false   -- 已写好 $96，等装关
local fast = false     -- 这次装关不要揭幕动画
local start_level = math.max(1, math.min(LEVELS, tonumber(os.getenv("LR_START_LEVEL")) or 1))

local function patch_loop(on)
  local code = on and { 0x4C, LOAD_LEVEL & 0xFF, LOAD_LEVEL >> 8 } or LOOP_CODE
  for i = 1, 3 do space:write_u8(LOOP_TOP + i - 1, code[i]) end
end

LR_KBD_TAP = space:install_read_tap(0xC000, 0xC000, "loderunner_kbd", function(offset, data, mask)
  if not enabled then return data end
  local pc = cpu.state["PC"].value
  if WAIT_KEY[pc] and reload and space:read_u8(WAIT_ARG) == START_BLINK and space:read_u8(MODE) == 2 then
    return STOP
  end
  if pc ~= READ_KEY then return data end
  local k = dig or dir
  if k then
    if dig then dig = nil else dir = nil end
    return k
  end
  if MASKED[data & 0xFF] and not held("ctrl") then return data & 0x7F end
  return data
end)

-- 装关时（不管是选关、死了还是过关）把 $60E4 改回来，这次装关不要揭幕动画、不限速
LR_LOAD_TAP = space:install_read_tap(DO_LOAD, DO_LOAD, "loderunner_load", function(offset, data, mask)
  if reload then
    reload, fast = false, true
    patch_loop(false)
    m.video.throttled = false  -- 逐格画关卡要 1.3 秒左右，关掉限速一下子画完
  end
  return data
end)

-- 揭幕：跳过收圈，开圈时先把第二页的关卡区拷到第一页，再让它只画最后一圈。
-- 选关时如果正在揭幕（旧关），也这样立即揭完，好让游戏走到等按键那里去换关。
LR_IRIS_TAP = space:install_read_tap(IRIS, IRIS_OPEN, "loderunner_iris", function(offset, data, mask)
  if not (fast or reload) then return data end
  if offset == IRIS then
    space:write_u8(IRIS_SHOWN, 0)
  elseif offset == IRIS_CLOSE then
    space:write_u8(IRIS_R, 1)
  elseif offset == IRIS_OPEN and space:read_u8(IRIS_R) < IRIS_MAX - 1 then
    for y = 0, 175 do  -- 只拷关卡区，下面 16 行是刚画好的状态栏
      local row = ((y & 7) << 10) | (((y >> 3) & 7) << 7) | ((y >> 6) * 40)
      for x = 0, 39 do space:write_u8(0x2000 + row + x, space:read_u8(0x4000 + row + x)) end
    end
    space:write_u8(IRIS_R, IRIS_MAX - 1)
    if fast then fast = false; m.video.throttled = true end
  end
  return data
end)

-- 开局写 $96=0、$A6=1、$9D=1 时换成起始关卡（$9D 清零）
local START_WRITE = { [GAME_START] = LEVEL, [GAME_START + 3] = LEVEL_SHOWN, [GAME_START + 5] = HISCORE_OK }
LR_START_TAP = space:install_write_tap(LEVEL, LEVEL_SHOWN, "loderunner_start", function(offset, data, mask)
  if start_level == 1 or START_WRITE[cpu.state["PC"].value] ~= offset then return end
  if offset == LEVEL then return start_level - 1 end
  if offset == LEVEL_SHOWN then return start_level end
  return 0
end)

LR_CTRL_FRAME = emu.register_frame_done(function()
  if not enabled then return end
  local now = m.time:as_double()
  if reload and space:read_u8(MODE) ~= 2 then  -- 还没换好这局就结束了
    reload, target = false, nil
    patch_loop(false)
  end
  for _, d in ipairs({ "level_up", "level_down" }) do
    local h = held(d)
    if h and not level_was[d] and space:read_u8(MODE) == 2 then
      local step = (held("shift") and 10 or 1) * (d == "level_up" and 1 or -1)
      target = math.max(1, math.min(LEVELS, (target or space:read_u8(LEVEL) + 1) + step))
      changed_at = now
    end
    level_was[d] = h
  end
  if target and now - changed_at >= 0.4 then
    if target ~= space:read_u8(LEVEL) + 1 then
      space:write_u8(LEVEL, target - 1)
      space:write_u8(LEVEL_SHOWN, target)
      space:write_u8(HISCORE_OK, 0)
      reload = true
      patch_loop(true)
    end
    target = nil
  end
  if target or reload then show_until = now + 1.5 end
  if now < show_until then
    m.screens[":screen"]:draw_text(4, 4, string.format("LEVEL %03d", target or space:read_u8(LEVEL) + 1),
      0xffffffff, 0xc0000000)
  end
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
  print("Lode Runner controls: 方向键移动，Z/X（或 U/O）向左/向右挖洞，PgUp/PgDn 选关（Shift ±10）" ..
    (start_level > 1 and "，从第 " .. start_level .. " 关开始" or ""))
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
