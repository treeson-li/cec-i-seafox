-- 《海战》向左发射（原版只有向前，也就是向右发射）
--
-- 向前发射（$78ED）创建 2 型对象：形状描述符指针 $16A9/$16AA = $8C09，x 在 $16AB/$16AC。
-- 移动在 $7F20：每节拍 x += $7F8A（=4），x 超过 $0134（右边界）时游戏把它移除。
-- 形状描述符：+0 颜色异或，+1 模式，+2/+3 x，+4 y，+5 宽（字节），+6 高，+7 每个移位副本的字节数，
-- +8 起是 7 个移位副本（Apple II 高分辨率每字节 7 个像素，低位在左）。
--
-- 做法（不修改游戏代码）：
-- 1. 把 $8C09 的鱼雷图形左右镜像，生成新的描述符放在 $0300（游戏运行时不用这块内存，实测无读写）。
-- 2. 控制层注入"向前发射"键并标记为向左；游戏创建对象时（写 $1D6C,y），
--    把它的形状指针换成镜像描述符，起点移到潜艇左侧。形状指针同时充当"向左"标记，
--    对象表压缩搬移时会跟着一起搬，不会丢。
-- 3. 读 tap 拦截 $7F8A：当前对象是向左的就让游戏加 -4（见下方说明）。
--    越过左边界后 x 回绕成 $FFxx，游戏自己的"超出右边界"检查会把它移除。

local m = manager.machine
local cpu = m.devices[":maincpu"]
local space = cpu.spaces["program"]

local RIGHT_DESC = 0x8C09
local LEFT_DESC = 0x0300
local LEFT_LO, LEFT_HI = LEFT_DESC & 0xFF, LEFT_DESC >> 8

-- 从移位 0 的副本取出每行像素，镜像后按原格式重新生成 7 个移位副本
local function build_left_shape()
  local hdr = {}
  for i = 0, 7 do hdr[i] = space:read_u8(RIGHT_DESC + i) end
  local w, h, per = hdr[5], hdr[6], hdr[7]
  local data = {}
  for i = 0, 7 * per - 1 do data[i] = space:read_u8(RIGHT_DESC + 8 + i) end

  local rows, width, hibit = {}, 0, data[0] & 0x80
  for r = 0, h - 1 do
    rows[r] = {}
    for p = 0, w * 7 - 1 do
      local b = data[r * w + p // 7]
      if (b >> (p % 7)) & 1 == 1 then rows[r][p] = true; if p + 1 > width then width = p + 1 end end
    end
  end
  local function render(pixels_of)
    local out = {}
    for s = 0, 6 do
      for r = 0, h - 1 do
        local bytes = {}
        for i = 0, w - 1 do bytes[i] = hibit end
        for p in pairs(pixels_of(r)) do
          local q = p + s
          if q < w * 7 then bytes[q // 7] = bytes[q // 7] | (1 << (q % 7)) end
        end
        for i = 0, w - 1 do out[#out + 1] = bytes[i] end
      end
    end
    return out
  end
  -- 自检：用同样的方法重新生成原图，必须和游戏里的数据一致，否则说明格式理解有误
  local again = render(function(r) return rows[r] end)
  for i = 1, #again do
    if again[i] ~= data[i - 1] then
      print("Seafox leftfire: 鱼雷图形格式与预期不符，向左发射的鱼雷沿用朝右的原图形")
      for j = 0, 8 + 7 * per - 1 do space:write_u8(LEFT_DESC + j, space:read_u8(RIGHT_DESC + j)) end
      return width
    end
  end
  local left = render(function(r)
    local t = {}
    for p in pairs(rows[r]) do t[width - 1 - p] = true end
    return t
  end)
  for i = 0, 7 do space:write_u8(LEFT_DESC + i, hdr[i]) end
  for i = 1, #left do space:write_u8(LEFT_DESC + 7 + i, left[i]) end
  return width
end

local shape_width = 8
local active = false

-- 游戏创建向前发射对象的最后一步是 $79AF 的 STA $1D6C,Y
SEAFOX_LEFT_CREATE_TAP = space:install_write_tap(0x1D6C, 0x1D6C + 31 * 8, "seafox_left_create", function(offset, data, mask)
  if not active then return end
  local pc = cpu.state["PC"].value
  if pc < 0x7947 or pc > 0x79B2 then return end
  if not (seafox_pending_left and seafox_pending_left()) then return end
  local y = offset - 0x1D6C
  space:write_u8(0x16A9 + y, LEFT_LO)
  space:write_u8(0x16AA + y, LEFT_HI)
  local subx = space:read_u8(0x7E0C) + 256 * space:read_u8(0x7E0D)
  local x = subx - shape_width
  space:write_u8(0x16AB + y, x & 0xFF)
  space:write_u8(0x16AC + y, (x >> 8) & 0xFF)
end)

-- $7F8A 只在 $7F24 的 ADC 里读，此时 X 是对象偏移
SEAFOX_LEFT_MOVE_TAP = space:install_read_tap(0x7F8A, 0x7F8A, "seafox_left_move", function(offset, data, mask)
  if not active then return data end
  local x = cpu.state["X"].value
  if space:read_u8(0x16A9 + x) ~= LEFT_LO or space:read_u8(0x16AA + x) ~= LEFT_HI then return data end
  -- 游戏执行 LDA lo / ADC $7F8A / STA lo / LDA hi / ADC #0 / STA hi，低字节已读进 A，不能在这里改。
  -- 让它加 -data（$FC），并预先把高字节减 1：低字节 >= data 时进位为 1，高字节不变；
  -- 否则进位为 0，高字节正好借位减 1。
  space:write_u8(0x16AC + x, (space:read_u8(0x16AC + x) - 1) & 0xFF)
  return (256 - data) & 0xFF
end)

-- 游戏装载完成后调用
function seafox_leftfire_start()
  shape_width = build_left_shape()
  active = true
end
