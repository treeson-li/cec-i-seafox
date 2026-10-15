-- 《海战》方向键控制层（游戏开始后由 play_seafox.lua 调用 seafox_controls_start()）
--
-- 游戏原本的键盘控制是"锁存式"：按一次 U/I/K/,/M/N/H/Y 设定航向速度，按 J 停船。
-- 游戏在 $7043 处读 $C000，用 $7190 起的 11 项表（键字符指针, dx, dy）查键；
-- dx=$80 为向前开火（F），dx=$81 为向上开火（D）。
-- 这里每帧读电脑上的方向键，合成 8 方向；状态稳定后把对应的游戏键
-- 注入 $C000 的读取结果，松开全部方向键时注入停船键。
-- 方向键在模拟键盘上产生的 $88/$95/$8B/$8A（$88 = Ctrl-H 会反转水平方向）一律屏蔽。

local m = manager.machine
local cpu = m.devices[":maincpu"]
local space = cpu.spaces["program"]
local inp = m.input

local function code(tok) return inp:code_from_token(tok) end
local KEY = {
  up = code("KEYCODE_UP"), down = code("KEYCODE_DOWN"),
  left = code("KEYCODE_LEFT"), right = code("KEYCODE_RIGHT"),
  fire_fwd = code("KEYCODE_Z"), fire_up = code("KEYCODE_X"),
}
local MASKED = { [0x88] = true, [0x95] = true, [0x8B] = true, [0x8A] = true }
local SETTLE_FRAMES = 3   -- 方向组合需稳定这么多帧才生效，避免松开斜向时闪一下直行
local FIRE_REPEAT = 6     -- 按住开火键时每隔多少帧连发一次

-- 测试用：设置 SEAFOX_FAKE_KEYS 后由它提供按键状态，而不是读真实键盘
local held = function(name) return inp:code_pressed(KEY[name]) end

local queue = {}
local enabled = false
local DEBUG = os.getenv("SEAFOX_DEBUG") ~= nil

-- 从游戏自己的表里查键字符，这样游戏内改键后依然正确
local function key_for(dx, dy)
  for x = 0, 0x28, 4 do
    local a = 0x7190 + x
    if space:read_u8(a + 2) == dx and space:read_u8(a + 3) == dy then
      return space:read_u8(space:read_u16(a))
    end
  end
end

local function to_byte(v) return v < 0 and v + 256 or v end

SEAFOX_KBD_TAP = space:install_read_tap(0xC000, 0xC000, "seafox_kbd", function(offset, data, mask)
  if not enabled then return data end
  if #queue > 0 then return queue[1].key | 0x80 end
  if MASKED[data & 0xFF] then return data & 0x7F end
  return data
end)
SEAFOX_STROBE_TAP = space:install_read_tap(0xC010, 0xC010, "seafox_strobe", function(offset, data, mask)
  if enabled and #queue > 0 then
    local e = table.remove(queue, 1)
    if DEBUG then print(string.format("t=%.2f game took key %s", m.time:as_double(), string.char(e.key))) end
  end
  return data
end)

local cur, cand, cand_frames = nil, nil, 0
local fire_wait = { fire_fwd = 0, fire_up = 0 }

-- 游戏不读键时（如开场驶入动画）队列会积压：方向只保留最新一条，开火最多攒 2 发
local function push(k, is_dir)
  if not k then return end
  local e = { key = k & 0x7F, dir = is_dir, t = m.time:as_double() }
  local fires = 0
  for i = #queue, 1, -1 do
    if queue[i].dir and is_dir then table.remove(queue, i)
    elseif not queue[i].dir then fires = fires + 1 end
  end
  if is_dir or fires < 2 then queue[#queue + 1] = e end
end

SEAFOX_CTRL_FRAME = emu.register_frame_done(function()
  if not enabled then return end
  -- 开火键 0.3 秒内没被游戏读走就作废，免得开场动画后补发
  for i = #queue, 1, -1 do
    if not queue[i].dir and m.time:as_double() - queue[i].t > 0.3 then table.remove(queue, i) end
  end
  local dx = (held("right") and 2 or 0) - (held("left") and 2 or 0)
  local dy = (held("down") and 2 or 0) - (held("up") and 2 or 0)
  local dir = dx .. "," .. dy
  if dir == cand then cand_frames = cand_frames + 1 else cand, cand_frames = dir, 1 end
  if cand_frames == SETTLE_FRAMES and dir ~= cur then
    -- 首次（cur 为 nil）且没按方向键时不注入，免得一进游戏就发停船键
    if not (cur == nil and dir == "0,0") then
      push(key_for(to_byte(dx), to_byte(dy)), true)
    end
    cur = dir
  end
  for name, marker in pairs({ fire_fwd = 0x80, fire_up = 0x81 }) do
    if held(name) then
      if fire_wait[name] <= 0 then push(key_for(marker, 0), false); fire_wait[name] = FIRE_REPEAT end
      fire_wait[name] = fire_wait[name] - 1
    else
      fire_wait[name] = 0
    end
  end
end)

function seafox_controls_start()
  enabled = true
  print("Seafox controls: 方向键移动（可斜向），Z 向前开火，X 向上开火")
end

-- 测试钩子：SEAFOX_FAKE_KEYS="t0:keys;t1:keys;..."（秒:逗号分隔的键名），用于无界面验证
local fake = os.getenv("SEAFOX_FAKE_KEYS")
if fake then
  local plan = {}
  for t, ks in fake:gmatch("([%d%.]+):([%w_,]*)") do plan[#plan + 1] = { tonumber(t), ks } end
  held = function(name)
    local t, active = m.time:as_double(), ""
    for _, p in ipairs(plan) do if t >= p[1] then active = p[2] end end
    return ("," .. active .. ","):find("," .. name .. ",", 1, true) ~= nil
  end
end
