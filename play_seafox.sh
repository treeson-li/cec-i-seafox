#!/bin/sh
# 用法: ./play_seafox.sh [--original] [关卡 1-5]
#   ./play_seafox.sh              修改版，从第 1 关开始
#   ./play_seafox.sh 4            修改版，从第 4 关开始
#   ./play_seafox.sh --original   原版（原按键、原开火限制、原油耗、3 条命）
#   ./play_seafox.sh --original 5 原版，从第 5 关开始
#
# 标题/演示画面按空格开始。
# 修改版：方向键移动（同时按两个=斜向，松开=停船），游戏中空格向上、F 向右、D 向左发射，回车暂停/继续；
#   G/S 向右/向左发追踪鱼雷（同屏 1 枚，每发 2 发弹药，30 秒一发）；
#   原来的 U/I/K/,/M/N/H/Y/J 键照样能用。控制层见 tools/seafox_controls.lua，向左发射和追踪鱼雷见 tools/seafox_torpedoes.lua
#   向前发射不限颗数；向上发射默认同屏 1 颗，可用 SEAFOX_MAX_UP=2 放宽（每多 1 颗游戏速度减半）
#   停船时油耗减半（SEAFOX_IDLE_FUEL=10 恢复原版）；无限命（SEAFOX_INFINITE_LIVES=0 恢复原版）。
#   玩法修改见 tools/seafox_patches.lua
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
exec mame ceci -rompath roms -cass "$TAPE" -window -nomaximize -skip_gameinfo \
  -snapshot_directory snap -autoboot_script tools/play_seafox.lua
