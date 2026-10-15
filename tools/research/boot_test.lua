-- 开机 -> 截图 -> 输入 PRINT 2+3 -> 截图 -> 退出
local m = manager.machine
local t0 = nil
local step = 0
emu.register_frame_done(function()
  local t = m.time.seconds
  if step == 0 and t > 4 then m.video:snapshot(); step = 1
  elseif step == 1 then m.natkeyboard:post("PRINT 2+3\n"); step = 2; t0 = t
  elseif step == 2 and t > t0 + 3 then m.video:snapshot(); step = 3
  elseif step == 3 then m:exit() end
end)
