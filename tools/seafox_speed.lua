-- 《海战》节拍器：让游戏按固定的节拍速度运行
--
-- 游戏没有定时器，主循环（$6CE3..$6D17）一圈就是一个节拍，跑完马上开始下一圈，所以速度完全取决于
-- 这一圈要算多久：东西少时快、东西多时慢（原版第 1 关每秒约 29~54 拍，第 5 关最慢约 5 拍）。
-- 这里在每圈结尾加一个等待：距上一拍不到 1/TICK_RATE 秒就等着，于是东西少时不会变快。
-- 东西多时要靠 CPU 算得够快才能不变慢，见 seafox_accel（TransWarp 加速卡）。
--
-- 做法（不修改游戏代码）：主循环结尾是 $6D17 的 JMP $6CE3。游戏取这条指令的操作数时，读 tap 让它读到 $0200，
-- 于是跳到放在 $0200 的一小段等待代码（游戏运行时不用这块内存）：
--   $0200  LDA $02F0   ; 读 tap：到时间了读出 1，否则读出 0
--   $0203  BEQ $0200
--   $0205  JMP $6CE3   ; 回到主循环开头
-- 时间用的是模拟机器的时间，MAME 正常限速运行时就等于真实时间。

local m = manager.machine
local space = m.devices[":maincpu"].spaces["program"]

local TICK_RATE = tonumber(os.getenv("SEAFOX_TICK_RATE")) or 17.5   -- 每秒节拍数，0 表示不限速（原版行为）
local STUB, FLAG = 0x0200, 0x02F0
local LOOP_TOP = 0x6CE3

local active = false
local next_tick = 0

-- $6D17 的 JMP 操作数（低、高字节）
SEAFOX_SPEED_JMP_TAP = space:install_read_tap(0x6D18, 0x6D19, "seafox_speed_jmp", function(offset, data, mask)
  if not active then return data end
  if offset == 0x6D18 and data == (LOOP_TOP & 0xFF) then return STUB & 0xFF end
  if offset == 0x6D19 and data == (LOOP_TOP >> 8) then return STUB >> 8 end
  return data
end)

SEAFOX_SPEED_FLAG_TAP = space:install_read_tap(FLAG, FLAG, "seafox_speed_flag", function(offset, data, mask)
  if not active then return 1 end
  local now = m.time:as_double()
  if now < next_tick then return 0 end
  -- 下一拍从"上一拍应到的时间"算起，保持平均速度；落后太多（比如刚暂停过）就从现在重新算，不补拍
  next_tick = next_tick + 1 / TICK_RATE
  if next_tick < now then next_tick = now + 1 / TICK_RATE end
  return 1
end)

-- 游戏装载完成后调用
function seafox_speed_start()
  if TICK_RATE <= 0 then return end
  local code = { 0xAD, FLAG & 0xFF, FLAG >> 8, 0xF0, 0xFB, 0x4C, LOOP_TOP & 0xFF, LOOP_TOP >> 8 }
  for i, b in ipairs(code) do space:write_u8(STUB + i - 1, b) end
  next_tick = m.time:as_double()
  active = true
end
