-- 《海战》CPU 加速：用 MAME 模拟的 Applied Engineering TransWarp 加速卡（插在 sl4）
--
-- 插了 TransWarp 后，程序在卡上的 65C02 里跑（全速约 3.58 MHz，原机 1.02 MHz），主板的 6502 停着。
-- 卡上 CPU 访问内存走主板的地址空间（a2bus DMA），所以其他脚本装在 :maincpu 地址空间上的 tap 照样生效，
-- 只是读寄存器（PC、X）要读卡上的 CPU，见 seafox_cpu()。
-- 卡的速度由软件写 $C074 控制：0 = 加速，1 = 1 MHz。只有卡上 CPU 自己的写才会被卡截获，
-- 所以这里通过卡上 CPU 的地址空间去写。
--
-- 什么时候不加速：
-- - 装磁带时：读带程序靠数 CPU 周期来量磁带信号，加速会读错。游戏进入 $67D4 后才开加速。
-- - 发声时：游戏用延时循环拨扬声器（$664C 每次播放一个音符），加速会让音调变高、声音变短。
--   进入 $664C 时切到 1 MHz，执行到它的 RTS（$667D）时恢复加速。主循环里平时不碰扬声器。
-- 没插卡（没有 a2twarp.zip，或原版）时这里什么都不做。配合 seafox_speed.lua 的节拍器，前期不会变快。

local m = manager.machine
local main = m.devices[":maincpu"]
local tw = m.devices[":sl4:twarp:tw65c02"]

-- 当前在执行游戏程序的 CPU（读 PC、X 等寄存器用）
function seafox_cpu() return tw or main end

if not tw then
  function seafox_accel_start() end
  return
end

local space = main.spaces["program"]
local tw_space = tw.spaces["program"]
local SOUND_ENTRY, SOUND_RTS = 0x664C, 0x667D

local function set_fast(on) tw_space:write_u8(0xC074, on and 0 or 1) end

local active = false

-- 装载期间保持 1 MHz：卡复位后默认是加速的
set_fast(false)
SEAFOX_ACCEL_BOOT = emu.register_frame_done(function()
  if not active then set_fast(false) end
end)

-- 只认取指令时的读取（PC 正好在这条指令上），免得别处把这里当数据读时误触发
local function at(addr) local pc = tw.state["PC"].value; return pc == addr or pc == addr + 1 end

SEAFOX_ACCEL_SOUND_IN = space:install_read_tap(SOUND_ENTRY, SOUND_ENTRY, "seafox_accel_sound_in", function(offset, data, mask)
  if active and at(SOUND_ENTRY) then set_fast(false) end
  return data
end)
SEAFOX_ACCEL_SOUND_OUT = space:install_read_tap(SOUND_RTS, SOUND_RTS, "seafox_accel_sound_out", function(offset, data, mask)
  if active and at(SOUND_RTS) then set_fast(true) end
  return data
end)

-- 游戏装载完成后调用
function seafox_accel_start()
  active = true
  set_fast(true)
end
