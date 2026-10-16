-- 《海战》玩法修改：放宽"同一时间只能有一颗"的开火限制
--
-- 向上发射（$784C）检查 $7EC1 < $7EC2，向前发射（$78ED）检查 $7F8D < $7F8E，
-- 原版这两个上限都是 1。它们只在开火检查时各读一次，这里用读 tap 改掉读到的值，不改游戏代码。
-- 所有子弹、敌船、深水炸弹共用 $16A8 起的 32 槽对象表（每槽 8 字节，$16A6 为已用槽数），
-- 游戏添加对象时不检查表满，所以对象数接近上限时让上限读成 0（暂时不能开火），
-- 给敌人留出槽位，避免越界破坏内存。

local m = manager.machine
local space = m.devices[":maincpu"].spaces["program"]

local SLOT_LIMIT = 24          -- 已用槽数达到这个值就暂停开火（表共 32 槽）
-- 实测（每秒游戏节拍）：向上发射 1 颗约 45、2 颗约 22、3 颗约 12，每颗都拖着要重绘的尾迹，
-- 多一颗速度就减半；向前发射很便宜，12~15 颗同屏仍约 30，默认不限。
-- 插了 TransWarp 加速卡（见 seafox_accel.lua）时同屏 3 颗也能保持每秒约 28 拍以上，所以默认 3 颗；没插卡默认 1 颗。
local accelerated = m.devices[":sl4:twarp:tw65c02"] ~= nil
local MAX_UP = tonumber(os.getenv("SEAFOX_MAX_UP")) or (accelerated and 3 or 1)
local MAX_FWD = tonumber(os.getenv("SEAFOX_MAX_FWD")) or 255

local function limiter(max)
  return function(offset, data, mask)
    if space:read_u8(0x16A6) >= SLOT_LIMIT then return 0 end
    return max
  end
end

-- 只在开火检查那条指令读取时生效（$7852 读 $7EC2，$78F3 读 $7F8E）
SEAFOX_UP_LIMIT_TAP = space:install_read_tap(0x7EC2, 0x7EC2, "seafox_up_limit", limiter(MAX_UP))
SEAFOX_FWD_LIMIT_TAP = space:install_read_tap(0x7F8E, 0x7F8E, "seafox_fwd_limit", limiter(MAX_FWD))

-- 油耗：原版不管动不动，每 9 个游戏节拍都扣 $7E1B（BCD 10）点油（$7D25 处），两次接不到加油船就会耗光。
-- 改成停船（航速 $7E15/$7E16 都为 0）时只扣一半。$7E1B 只在这条扣油指令里读一次。
-- 扣油量不超过剩余油量，免得剩 5 点时扣 10 在 BCD 里下溢成 9995、永远不会没油。
local IDLE_FUEL = tonumber(os.getenv("SEAFOX_IDLE_FUEL")) or 5

local function bcd(v) return (v >> 4) * 10 + (v & 0x0F) end

SEAFOX_FUEL_TAP = space:install_read_tap(0x7E1B, 0x7E1B, "seafox_fuel", function(offset, data, mask)
  local cost = bcd(data)
  if space:read_u8(0x7E15) == 0 and space:read_u8(0x7E16) == 0 then cost = IDLE_FUEL end
  local fuel = bcd(space:read_u8(0x14F1)) * 100 + bcd(space:read_u8(0x14F0))
  if space:read_u8(0x7E1C) == 0 and cost > fuel then cost = fuel end
  return (cost // 10) * 16 + cost % 10
end)

-- 无限命：$71C3 是剩余命数，每局开始设为 3（$69DA），每死一次 $6C2E 处 DEC 一次，
-- $6D5F 读到 0 就结束游戏。写 tap 把小于 3 的写入改回 3。SEAFOX_INFINITE_LIVES=0 恢复原版。
if os.getenv("SEAFOX_INFINITE_LIVES") ~= "0" then
  SEAFOX_LIVES_TAP = space:install_write_tap(0x71C3, 0x71C3, "seafox_lives", function(offset, data, mask)
    if data < 3 then return 3 end
  end)
end
