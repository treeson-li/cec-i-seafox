-- 自动装载《海战》：POKE A1/A2 -> CALL $D146（CEC-I ROM 中的 Apple 兼容读带例程）-> 放带
-- 装载期间关闭限速加快速度，重定位完成即将进入 $67D4 时恢复正常速度并停带
-- SEAFOX_ORIGINAL=1 时为原版：不加载方向键控制层和玩法修改
local original = os.getenv("SEAFOX_ORIGINAL") == "1"
if not original then
  dofile("tools/seafox_controls.lua")
  dofile("tools/seafox_patches.lua")
  dofile("tools/seafox_leftfire.lua")
end
local m = manager.machine
local cpu = m.devices[":maincpu"]
local cass = m.cassettes[":tape"]
local enter_at = tonumber(os.getenv("ENTER_AT")) or 6.5
local step, t0 = 0, 0
SEAFOX_PLAY_TAP = cpu.spaces["program"]:install_read_tap(0xC052, 0xC052, "seafox", function(o, d, mk)
  local pc = cpu.state["PC"].value
  if step == 3 and pc >= 0x2900 and pc < 0x2950 then
    step = 4; cass:stop(); m.video.throttled = true
    print("Seafox loaded, starting game at $67D4" .. (original and " (original)" or ""))
    if not original then seafox_controls_start(); seafox_leftfire_start() end
  end
  return d
end)
emu.register_frame_done(function()
  local t = m.time.seconds
  if step == 0 and t > 3 then
    m.natkeyboard:post("POKE 60,48:POKE 61,0:POKE 62,255:POKE 63,3:CALL 53574"); step = 1; t0 = t
  elseif step == 1 and t > t0 + 3 then
    cass:play(); m.video.throttled = false; step = 2
  elseif step == 2 and cass.position > enter_at then
    m.natkeyboard:post("\n"); step = 3
  end
end)
