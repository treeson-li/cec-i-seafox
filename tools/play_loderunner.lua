-- 自动装载《警察抓小偷》(Lode Runner)：POKE A1/A2 -> CALL $D146 读 R1 -> 磁带上的 $0300 例程接着读 R2、R3
-- 用的是 tools/loderunner_tape.py 合成的干净磁带。装载期间关闭限速，进入游戏（$0DE7）时停带并恢复正常速度。
local m = manager.machine
local cpu = m.devices[":maincpu"]
local space = cpu.spaces["program"]
local cass = m.cassettes[":tape"]
-- R1 的同步位在 5.5 秒；ROM 读带例程开头固定延时约 3.5 秒才开始找同步位，所以要在 2 秒前按回车
local enter_at = tonumber(os.getenv("ENTER_AT")) or 1.2
local GAME_ENTRY = 0x0DE7
local step = 0
dofile("tools/loderunner_controls.lua")

-- $0257 搬完数据后 JMP $0DE7 进入游戏
LR_ENTRY_TAP = space:install_read_tap(GAME_ENTRY, GAME_ENTRY, "loderunner_entry", function(o, d, mk)
  if step == 3 and cpu.state["PC"].value == GAME_ENTRY then
    step = 4; cass:stop(); m.video.throttled = true
    lr_controls_start()
    print("Lode Runner loaded, starting game at $0DE7")
  end
  return d
end)
LR_FRAME = emu.register_frame_done(function()
  -- 等 BASIC 提示符出来、CPU 在 Monitor 的 KEYIN（$FD1B 起）等按键时再输入；命令先打好不按回车
  local pc = cpu.state["PC"].value
  if step == 0 and m.time.seconds > 3 and (pc >= 0xFD1B and pc < 0xFD30 or m.time.seconds > 15) then
    m.natkeyboard:post("POKE 60,48:POKE 61,0:POKE 62,255:POKE 63,3:CALL 53574"); step = 1
  elseif step == 1 and not m.natkeyboard.is_posting then
    cass:play(); m.video.throttled = false; step = 2
  elseif step == 2 and cass.position >= enter_at then
    m.natkeyboard:post("\n"); step = 3
  end
end)
