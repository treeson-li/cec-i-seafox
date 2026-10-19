#!/bin/sh
# 用法: ./play_seafox.sh [--original] [关卡 1-5]
#   ./play_seafox.sh              修改版，从第 1 关开始
#   ./play_seafox.sh 4            修改版，从第 4 关开始
#   ./play_seafox.sh --original   原版（原按键、原开火限制、原油耗、3 条命）
#   ./play_seafox.sh --original 5 原版，从第 5 关开始
#
# 标题/演示画面按空格开始。
# 修改版：方向键移动（同时按两个=斜向，松开=停船），游戏中空格向上、F 向右、D 向左发射，回车暂停/继续；
#   第 4 关起 G 发追踪鱼雷（追右侧的敌潜艇，同屏 1 枚，每发 2 发弹药）；
#   原来的 U/I/K/,/M/N/H/Y/J 键照样能用。控制层见 tools/seafox_controls.lua，向左发射和追踪鱼雷见 tools/seafox_torpedoes.lua
#   向前发射不限颗数；向上发射同屏 3 颗、每秒最多 1 发（SEAFOX_UP_INTERVAL 可改；没有加速卡时 1 颗，每多 1 颗游戏速度减半），SEAFOX_MAX_UP 可改
#   潜艇航速提高 50%（SEAFOX_SUB_SPEED=1 恢复原版）；停船时油耗减半（SEAFOX_IDLE_FUEL=10 恢复原版）；无限命（SEAFOX_INFINITE_LIVES=0 恢复原版）。
#   玩法修改见 tools/seafox_patches.lua
#   速度：固定每秒 17.5 拍（SEAFOX_TICK_RATE 可调，0 = 原版不限速）；有 roms/a2twarp.zip 时插 TransWarp 加速卡，
#   后期东西多也不变慢（SEAFOX_ACCEL=0 不插）。见 tools/seafox_speed.lua、tools/seafox_accel.lua
# 退出：先按 Fn+Delete（MAME 的 UI 切换键）再按 Esc。
cd "$(dirname "$0")"
SEAFOX_ORIGINAL=0
SEAFOX_START_MISSION=1
for arg in "$@"; do
  case "$arg" in
    --original) SEAFOX_ORIGINAL=1 ;;
    [1-5]) SEAFOX_START_MISSION=$arg ;;
    *) echo "未知参数: $arg"; echo "用法: $0 [--original] [关卡 1-5]"; exit 1 ;;
  esac
done
export SEAFOX_ORIGINAL SEAFOX_START_MISSION
# 两面磁带内容相同，固定用 A 面（B 面是备份，要用的话改这里并把 ENTER_AT 设为 4.0）
TAPE="tapes/Face A.wav"; export ENTER_AT=6.5

if [ ! -f "$TAPE" ] || [ ! -f roms/ceci.zip ]; then
  echo "缺少磁带或 ROM，请先运行 ./setup.sh"; exit 1
fi
# 修改版插 TransWarp 加速卡（需要 roms/a2twarp.zip）
CARD=""
if [ $SEAFOX_ORIGINAL = 0 ] && [ "${SEAFOX_ACCEL:-1}" != 0 ]; then
  if [ -f roms/a2twarp.zip ]; then CARD="-sl4 twarp"
  else echo "没有 roms/a2twarp.zip，不加速运行（后期关卡会变慢），见 README"; fi
fi
exec mame ceci -rompath roms $CARD -cass "$TAPE" -window -maximize -skip_gameinfo \
  -snapshot_directory snap -autoboot_script tools/play_seafox.lua
