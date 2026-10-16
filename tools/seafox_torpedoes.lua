-- 《海战》向左发射和追踪鱼雷（原版只有向前，也就是向右发射）
--
-- 向前发射（$78ED）创建 2 型对象：形状描述符指针 $16A9/$16AA = $8C09，x 在 $16AB/$16AC，y 在 $16AD。
-- 移动在 $7EC7：每节拍 x += $7F8A（=4），每 $7F93（=5）个节拍 y += $17AB（发射时潜艇纵向速度的一半），
-- y 限制在 $7F94..$7F95（45..178，水下）；x 超过 $0134（右边界）时游戏把它移除。
-- 形状描述符：+0 颜色异或，+1 模式，+2/+3 x，+4 y，+5 宽（字节），+6 高，+7 每个移位副本的字节数，
-- +8 起是 7 个移位副本（Apple II 高分辨率每字节 7 个像素，低位在左，最高位选调色板）。
--
-- 做法（不修改游戏代码）：
-- 1. 由 $8C09 的鱼雷图形生成三个新描述符放在 $0300 起（游戏运行时不用这块内存，实测无读写）：
--    向左（镜像）、追踪向右、追踪向左（换调色板，颜色和普通鱼雷不同）。
-- 2. 控制层注入"向前发射"键并标记种类；游戏创建对象时（写 $1D6C,y），换形状指针、调整起点。
--    形状指针同时充当种类标记，对象表压缩搬移时会跟着一起搬，不会丢。
-- 3. 读 tap 拦截 $7F8A：向左的让游戏加 -4（见下方说明）。追踪鱼雷左右方向在发射时定死（G 向右、S 向左），
--    不掉头，每节拍横向走 6；同时找前方（飞行方向上）离它最近的敌潜艇，上下直接改 y（每节拍最多 4）对准它。
--    前方没有敌潜艇就直线飞，越界后由游戏移除。
--    越过左边界后 x 回绕成 $FFxx，游戏自己的"超出右边界"检查会把它移除。
-- 追踪鱼雷：同屏 1 枚，每发扣 2 发弹药。

local m = manager.machine
local cpu = m.devices[":maincpu"]
local space = cpu.spaces["program"]

local RIGHT_DESC = 0x8C09
local LEFT_DESC, HOMING_R, HOMING_L = 0x0300, 0x0340, 0x0380
local HOMING_AMMO = 2          -- 每发扣的弹药（游戏自己扣 1，这里多扣 1）
local HOMING_DY = 4            -- 每节拍上下最多移动的像素（方向不能掉头，2 太小，迎面来的敌潜艇常常对不准）
local HOMING_DX = 6            -- 每节拍左右移动的像素（普通鱼雷 4；敌潜艇逃跑时比 4 快，追不上）
-- 追踪的目标：只追敌潜艇（3 型）。敌方追踪导弹、瞄准弹、水面目标舰、加油船等都不追
-- （途中撞上的照样会炸，碰撞由游戏自己判断）
local TARGET_TYPES = { [3] = true }
local Y_MIN, Y_MAX = 0x2D, 0xB2
-- 对象状态 $16AE 的位：$80 已出场（没出场的瞄准弹在屏幕右侧待命，不能当目标），$02 爆炸中，$04 待移除
local ST_VISIBLE, ST_EXPLODING, ST_REMOVING = 0x80, 0x02, 0x04

local function read16(a) return space:read_u8(a) + 256 * space:read_u8(a + 1) end
local function ptr_of(x) return read16(0x16A9 + x) end
local function set_ptr(x, p) space:write_u8(0x16A9 + x, p & 0xFF); space:write_u8(0x16AA + x, p >> 8) end

-- 从移位 0 的副本取出每行像素，按需镜像、换调色板后按原格式重新生成 7 个移位副本
local function build_shapes()
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
  local function render(mirror, hb)
    local out = {}
    for s = 0, 6 do
      for r = 0, h - 1 do
        local bytes = {}
        for i = 0, w - 1 do bytes[i] = hb end
        for p in pairs(rows[r]) do
          local q = (mirror and width - 1 - p or p) + s
          if q < w * 7 then bytes[q // 7] = bytes[q // 7] | (1 << (q % 7)) end
        end
        for i = 0, w - 1 do out[#out + 1] = bytes[i] end
      end
    end
    return out
  end
  local function store(dest, bytes)
    for i = 0, 7 do space:write_u8(dest + i, hdr[i]) end
    for i = 1, #bytes do space:write_u8(dest + 7 + i, bytes[i]) end
  end
  -- 自检：用同样的方法重新生成原图，必须和游戏里的数据一致，否则说明格式理解有误
  local again = render(false, hibit)
  for i = 1, #again do
    if again[i] ~= data[i - 1] then
      print("Seafox torpedoes: 鱼雷图形格式与预期不符，新鱼雷沿用原图形")
      local orig = {}
      for j = 0, 7 * per - 1 do orig[j + 1] = data[j] end
      for _, dest in ipairs({ LEFT_DESC, HOMING_R, HOMING_L }) do store(dest, orig) end
      return width, h
    end
  end
  local other = hibit ~ 0x80
  store(LEFT_DESC, render(true, hibit))
  store(HOMING_R, render(false, other))
  store(HOMING_L, render(true, other))
  return width, h
end

local shape_width, shape_height = 8, 3
local active = false

local function is_homing(p) return p == HOMING_R or p == HOMING_L end

local function homing_in_flight()
  for i = 0, space:read_u8(0x16A6) - 1 do
    local x = i * 8
    if space:read_u8(0x16A8 + x) == 2 and is_homing(ptr_of(x)) then return true end
  end
  return false
end

-- 给 seafox_controls.lua 用：现在能不能发追踪鱼雷（弹药够不够由游戏自己判断，见下方弹药 tap）
function seafox_homing_ready()
  return active and not homing_in_flight()
end

local function pending_kind() return seafox_pending_kind and seafox_pending_kind() end

-- 发射时的扣弹药：$7921 LDA $14EF / BEQ 没弹药 / SED SBC #1 / STA $14EF，然后刷新显示。
-- 追踪鱼雷让这里读出的弹药少 1：只剩 1 发时读成 0，游戏当作没弹药不发射；否则一共扣 2 发。
SEAFOX_HOMING_AMMO_TAP = space:install_read_tap(0x14EF, 0x14EF, "seafox_homing_ammo", function(offset, data, mask)
  if not active then return data end
  local pc = cpu.state["PC"].value
  if pc < 0x7915 or pc > 0x7930 then return data end
  local k = pending_kind()
  if k ~= "homing_right" and k ~= "homing_left" then return data end
  local v = (data >> 4) * 10 + (data & 0x0F) - (HOMING_AMMO - 1)
  if v < 0 then v = 0 end
  return (v // 10) * 16 + v % 10
end)

-- 游戏创建向前发射对象的最后一步是 $79AF 的 STA $1D6C,Y
SEAFOX_TORPEDO_CREATE_TAP = space:install_write_tap(0x1D6C, 0x1D6C + 31 * 8, "seafox_torpedo_create", function(offset, data, mask)
  if not active then return end
  local pc = cpu.state["PC"].value
  if pc < 0x7947 or pc > 0x79B2 then return end
  local k = pending_kind()
  if k ~= "left" and k ~= "homing_right" and k ~= "homing_left" then return end
  local y = offset - 0x1D6C
  if k == "homing_right" then
    set_ptr(y, HOMING_R)
  else
    set_ptr(y, k == "left" and LEFT_DESC or HOMING_L)
    local x = read16(0x7E0C) - shape_width
    space:write_u8(0x16AB + y, x & 0xFF)
    space:write_u8(0x16AC + y, (x >> 8) & 0xFF)
  end
  if k ~= "left" then
    space:write_u8(0x17AB + y, 0)   -- 不继承潜艇的纵向速度，上下由追踪逻辑控制
  end
end)

-- 找 (mx, my) 前方（going_left 为真时是左边，否则右边）最近的追踪目标，返回它的中心
local function find_target(mx, my, going_left)
  local best, bx, by
  for i = 0, space:read_u8(0x16A6) - 1 do
    local o = i * 8
    local st = space:read_u8(0x16AE + o)
    if TARGET_TYPES[space:read_u8(0x16A8 + o)] and st & ST_VISIBLE ~= 0 and st & (ST_EXPLODING | ST_REMOVING) == 0 then
      local p = ptr_of(o)
      local tx = read16(0x16AB + o) + space:read_u8(p + 5) * 7 // 2
      local ty = space:read_u8(0x16AD + o) + space:read_u8(p + 6) // 2
      if tx < 0x8000 and (going_left and tx < mx or not going_left and tx > mx) then
        local d = math.abs(tx - mx) + math.abs(ty - my)
        if not best or d < best then best, bx, by = d, tx, ty end
      end
    end
  end
  return bx, by
end

-- 每节拍调用一次：上下对准前方最近的敌潜艇，直接改 y
local function steer(x, going_left)
  local mx = space:read_u8(0x16AB + x) + 256 * space:read_u8(0x16AC + x) + shape_width // 2
  local my = space:read_u8(0x16AD + x) + shape_height // 2
  local tx, ty = find_target(mx, my, going_left)
  if not tx then return end
  local dy = ty - my
  if dy > HOMING_DY then dy = HOMING_DY elseif dy < -HOMING_DY then dy = -HOMING_DY end
  local ny = space:read_u8(0x16AD + x) + dy
  if ny < Y_MIN then ny = Y_MIN elseif ny > Y_MAX then ny = Y_MAX end
  space:write_u8(0x16AD + x, ny)
end

-- $7F8A 只在 $7F24 的 ADC 里读，此时 X 是对象偏移
SEAFOX_TORPEDO_MOVE_TAP = space:install_read_tap(0x7F8A, 0x7F8A, "seafox_torpedo_move", function(offset, data, mask)
  if not active then return data end
  local x = cpu.state["X"].value
  local p = ptr_of(x)
  local left, step = nil, data
  if p == LEFT_DESC then
    left = true
  elseif is_homing(p) then
    left = p == HOMING_L
    steer(x, left)
    step = HOMING_DX
  else
    return data
  end
  if not left then return step end
  -- 游戏执行 LDA lo / ADC $7F8A / STA lo / LDA hi / ADC #0 / STA hi，低字节已读进 A，不能在这里改。
  -- 让它加 -step（如 $FC），并预先把高字节减 1：低字节 >= step 时进位为 1，高字节不变；
  -- 否则进位为 0，高字节正好借位减 1。
  space:write_u8(0x16AC + x, (space:read_u8(0x16AC + x) - 1) & 0xFF)
  return (256 - step) & 0xFF
end)

-- 游戏装载完成后调用
function seafox_torpedoes_start()
  shape_width, shape_height = build_shapes()
  active = true
end
