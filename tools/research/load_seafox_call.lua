-- CALL -151 -> 30.3FFR -> 放带 -> 回车；在 $67D4 首次取指时导出内存；定时截图
local m = manager.machine
local cpu = m.devices[":maincpu"]
local space = cpu.spaces["program"]
local cass = m.cassettes[":tape"]
local outdir = os.getenv("SEAFOX_OUT") or "."
local step, t0, nextsnap, hit = 0, 0, 0, false
SEAFOX_TAP = space:install_read_tap(0xC052, 0xC052, "entry", function(offset, data, mask)
  local pc = cpu.state["PC"].value
  if not hit and pc >= 0x2900 and pc < 0x2950 then
    hit = true
    local f = io.open(outdir .. "/mame_mem_at_67D4.bin", "wb")
    for a = 0, 0xBFFF do f:write(string.char(space:read_u8(a))) end
    f:close()
    print(string.format("RELOCATOR done (PC=$%04X), about to JMP $67D4 at t=%.2fs", pc, m.time.seconds))
  end
  return data
end)
emu.register_frame_done(function()
  local t = m.time.seconds
  if step == 0 and t > 3 then m.natkeyboard:post("POKE 60,48:POKE 61,0:POKE 62,255:POKE 63,3:CALL 53574"); step = 2; t0 = t
  elseif step == 1 and t > t0 + 1.5 then m.natkeyboard:post("30.3FFR"); step = 2; t0 = t
  elseif step == 2 and t > t0 + 1.5 then cass:play(); print(string.format("tape play at t=%.2f", t)); step = 3; t0 = t
  elseif step == 3 and cass.position > (tonumber(os.getenv("ENTER_AT")) or 6.5) then m.natkeyboard:post("\n"); print(string.format("RETURN at t=%.2f tape pos %.2f", t, cass.position)); step = 4
  elseif step == 4 then
    if t >= nextsnap then m.video:snapshot(); print(string.format("snap t=%.1f tape=%.1fs PC=$%04X", t, cass.position, cpu.state["PC"].value)); nextsnap = t + 20 end
    if (hit and t > nextsnap - 5 and t > 240) or t > 300 then m:exit() end
  end
end)
