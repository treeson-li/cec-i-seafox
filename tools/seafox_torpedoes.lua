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
--    画图程序 $1AF0 擦除时用的是上次画时保存的指针和坐标，所以飞行中换指针（掉头）不会留残影。
-- 3. 读 tap 拦截 $7F8A：向左的让游戏加 -4（见下方说明）。追踪鱼雷（G 键，向右发射）每节拍找
--    我方潜艇右侧、离鱼雷最近的敌潜艇并锁定，之后不换目标；目标没了就朝它最后的位置飞过去。横向有速度（最快 ±6）和固定的加速度（每节拍 1）：
--    目标在哪边就朝哪边加速，掉头时先减速到 0 再反向加速，像真实的物体一样画出一段弧线；
--    上下直接改 y（每节拍 2）。没有目标就保持原方向加速到最快直线飞，越界后由游戏移除。
--    越过左边界后 x 回绕成 $FFxx，游戏自己的"超出右边界"检查会把它移除。
-- 追踪鱼雷：第 4 关（敌潜艇开始放磁性炸弹，也就是 4 型追踪对象）起才能用；同屏 1 枚，每发扣 2 发弹药。

local m = manager.machine
local cpu = seafox_cpu()   -- 读寄存器用；插了加速卡时是卡上的 CPU，见 seafox_accel.lua
local space = m.devices[":maincpu"].spaces["program"]

local RIGHT_DESC = 0x8C09
local LEFT_DESC, HOMING_R, HOMING_L = 0x0300, 0x0340, 0x0380
local HOMING_AMMO = 2          -- 每发扣的弹药（游戏自己扣 1，这里多扣 1）
local HOMING_DY = 2            -- 每节拍上下最多移动的像素
local HOMING_DX = 6            -- 左右最快每节拍移动的像素（普通鱼雷 4；敌潜艇逃跑时比 4 快，追不上）
local HOMING_MIN_LEAD = 40      -- 锁定目标时，目标至少要在鱼雷前方这么多像素
local HOMING_ACCEL = tonumber(os.getenv("SEAFOX_HOMING_ACCEL")) or 1   -- 左右加速度（像素/节拍²）：从 +6 掉头到 -6 要 12 个节拍，
-- 掉头时多冲出去约 18 像素。0.5 时要冲出 36 像素，目标多从右边进场，鱼雷常在掉头前冲出右边界被移除
local HOMING_LIFETIME = 400    -- 追踪的节拍数，之后直线飞出屏幕，免得一直绕圈
local HOMING_FROM_MISSION = 4  -- 磁性炸弹（$81F4 上限）从第 4 关开始出现，追踪鱼雷也从这关起才能用
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
local homing_ticks = 0
local homing_vx, homing_frac = 0, 0   -- 追踪鱼雷的横向速度和不足 1 像素的位移余数（同屏只有一枚）
local DEBUG = os.getenv("SEAFOX_DEBUG") ~= nil
local target = nil   -- 锁定的目标 { x, y, vx, lost, reached }，见下方 acquire/track

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
  return active and space:read_u8(0x71C1) >= HOMING_FROM_MISSION and not homing_in_flight()
end

local function pending_kind() return seafox_pending_kind and seafox_pending_kind() end

-- 发射时的扣弹药：$7921 LDA $14EF / BEQ 没弹药 / SED SBC #1 / STA $14EF，然后刷新显示。
-- 追踪鱼雷让这里读出的弹药少 1：只剩 1 发时读成 0，游戏当作没弹药不发射；否则一共扣 2 发。
SEAFOX_HOMING_AMMO_TAP = space:install_read_tap(0x14EF, 0x14EF, "seafox_homing_ammo", function(offset, data, mask)
  if not active then return data end
  local pc = cpu.state["PC"].value
  if pc < 0x7915 or pc > 0x7930 then return data end
  local k = pending_kind()
  if k ~= "homing" then return data end
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
  if k ~= "left" and k ~= "homing" then return end
  local y = offset - 0x1D6C
  if k == "homing" then
    set_ptr(y, HOMING_R)
    space:write_u8(0x17AB + y, 0)   -- 不继承潜艇的纵向速度，上下由追踪逻辑控制
    homing_ticks, homing_vx, homing_frac, target = 0, HOMING_DX, 0, nil
  else
    set_ptr(y, LEFT_DESC)
    local x = read16(0x7E0C) - shape_width
    space:write_u8(0x16AB + y, x & 0xFF)
    space:write_u8(0x16AC + y, (x >> 8) & 0xFF)
  end
end)

-- 锁定的目标（同屏只有一枚追踪鱼雷）：发射后锁定我方潜艇右侧、离鱼雷最近的一艘敌潜艇，之后不再换。
-- 对象表会压缩搬移，槽位不固定，所以每节拍按"上次位置 + 它自己的速度"预测，在附近找同类对象认作同一艘。
-- 目标被击毁、开出屏幕或找不到了，就朝它最后出现的位置飞过去，到了以后保持方向直线飞。

local function sub_center(o)
  local p = ptr_of(o)
  return read16(0x16AB + o) + space:read_u8(p + 5) * 7 // 2, space:read_u8(0x16AD + o) + space:read_u8(p + 6) // 2
end

local function visible_subs()
  local list = {}
  for i = 0, space:read_u8(0x16A6) - 1 do
    local o = i * 8
    local st = space:read_u8(0x16AE + o)
    if TARGET_TYPES[space:read_u8(0x16A8 + o)] and st & ST_VISIBLE ~= 0 and st & ST_REMOVING == 0 then
      local tx, ty = sub_center(o)
      if tx < 0x8000 then
        local v = space:read_u8(0x17AB + o) + 256 * space:read_u8(0x17AC + o)
        if v >= 0x8000 then v = v - 0x10000 end
        list[#list + 1] = { x = tx, y = ty, vx = v, exploding = st & ST_EXPLODING ~= 0 }
      end
    end
  end
  return list
end

-- 还没锁定时：在我方潜艇右侧、没在爆炸的敌潜艇里挑一艘能"迎上去打"的，再从中选离 (mx, my) 最近的。
-- 能迎上去打：在鱼雷前方（右边）至少 HOMING_MIN_LEAD 像素，而且照双方现在的速度，
-- 鱼雷在和它横向相遇之前来得及把上下对准（每节拍 HOMING_DY）。
-- 太近或来不及对准的不选，免得刚锁定就交错而过、只能掉头追。都不满足就先直线飞，下个节拍再挑。
local function acquire(mx, my)
  local subx, best = read16(0x7E0C), nil
  for _, t in ipairs(visible_subs()) do
    local lead = t.x - mx
    local closing = homing_vx - t.vx          -- 每节拍横向接近多少像素
    if not t.exploding and t.x > subx and lead >= HOMING_MIN_LEAD and closing > 0
       and lead / closing >= math.abs(t.y - my) / HOMING_DY then
      local d = math.abs(t.x - mx) + math.abs(t.y - my)
      if not best or d < best.d then best = { d = d, t = t } end
    end
  end
  if best then
    target = { x = best.t.x, y = best.t.y, vx = best.t.vx }
    if DEBUG then print(string.format("homing: lock target at (%d,%d) vx=%d", target.x, target.y, target.vx)) end
  end
end

-- 已锁定时：更新目标位置；认不出来或已在爆炸就标记为丢失，保留最后位置
local function track()
  local px, best = target.x + target.vx, nil
  for _, t in ipairs(visible_subs()) do
    local dx, dy = math.abs(t.x - px), math.abs(t.y - target.y)
    if dx <= 12 and dy <= 4 and (not best or dx + dy < best.d) then best = { d = dx + dy, t = t } end
  end
  if not best or best.t.exploding then
    target.lost = true
    if DEBUG then print(string.format("homing: target lost, last (%d,%d)%s", target.x, target.y, best and " exploding" or "")) end
    return
  end
  target.x, target.y, target.vx = best.t.x, best.t.y, best.t.vx
end

-- 每节拍调用一次（同屏只有一枚）：按目标调整横向速度、直接改 y，返回这一步横向移动的整数像素
local function steer(x)
  homing_ticks = homing_ticks + 1
  -- 想去的方向：默认保持当前方向
  local want = homing_vx < 0 and -HOMING_DX or HOMING_DX
  if homing_ticks <= HOMING_LIFETIME then
    local mx = space:read_u8(0x16AB + x) + 256 * space:read_u8(0x16AC + x) + shape_width // 2
    local my = space:read_u8(0x16AD + x) + shape_height // 2
    if not target then acquire(mx, my) elseif not target.lost then track() end
    if target and target.lost and not target.reached
       and math.abs(target.x - mx) <= HOMING_DX and math.abs(target.y - my) <= HOMING_DY then
      target.reached = true   -- 到了目标最后的位置，之后直线飞
      if DEBUG then print("homing: reached last position") end
    end
    if target and not target.reached then
      local tx, ty = target.x, target.y
      if tx < mx - 4 then want = -HOMING_DX elseif tx > mx + 4 then want = HOMING_DX end
      local dy = ty - my
      if dy > HOMING_DY then dy = HOMING_DY elseif dy < -HOMING_DY then dy = -HOMING_DY end
      local ny = space:read_u8(0x16AD + x) + dy
      if ny < Y_MIN then ny = Y_MIN elseif ny > Y_MAX then ny = Y_MAX end
      space:write_u8(0x16AD + x, ny)
    end
  end
  -- 速度每节拍最多变化 HOMING_ACCEL
  if homing_vx < want then homing_vx = math.min(homing_vx + HOMING_ACCEL, want)
  elseif homing_vx > want then homing_vx = math.max(homing_vx - HOMING_ACCEL, want) end
  homing_frac = homing_frac + homing_vx
  local step = homing_frac >= 0 and math.floor(homing_frac) or -math.floor(-homing_frac)
  homing_frac = homing_frac - step
  return step
end

-- $7F8A 只在 $7F24 的 ADC 里读，此时 X 是对象偏移
SEAFOX_TORPEDO_MOVE_TAP = space:install_read_tap(0x7F8A, 0x7F8A, "seafox_torpedo_move", function(offset, data, mask)
  if not active then return data end
  local x = cpu.state["X"].value
  local p = ptr_of(x)
  local step
  if p == LEFT_DESC then
    step = -data
  elseif is_homing(p) then
    step = steer(x)
    if homing_vx ~= 0 then set_ptr(x, homing_vx < 0 and HOMING_L or HOMING_R) end   -- 图形朝向跟着速度方向
  else
    return data
  end
  if step >= 0 then return step end
  step = -step
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
