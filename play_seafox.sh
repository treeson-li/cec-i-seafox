#!/bin/sh
# 用法: ./play_seafox.sh [--original] [B]
#   ./play_seafox.sh              修改版，A 面磁带
#   ./play_seafox.sh B            修改版，B 面磁带
#   ./play_seafox.sh --original   原版（原按键、原开火限制、原油耗）
#
# 标题/演示画面按空格开始。
# 修改版：方向键移动（同时按两个=斜向，松开=停船），游戏中空格向上、F 向右、D 向左发射；
#   原来的 U/I/K/,/M/N/H/Y/J 键照样能用。控制层见 tools/seafox_controls.lua，向左发射见 tools/seafox_leftfire.lua
#   向前发射不限颗数；向上发射默认同屏 1 颗，可用 SEAFOX_MAX_UP=2 放宽（每多 1 颗游戏速度减半）
#   停船时油耗减半（SEAFOX_IDLE_FUEL=10 恢复原版）。玩法修改见 tools/seafox_patches.lua
# 退出：先按 Fn+Delete（MAME 的 UI 切换键）再按 Esc。
cd "$(dirname "$0")"
SIDE=A
SEAFOX_ORIGINAL=0
for arg in "$@"; do
  case "$arg" in
    --original) SEAFOX_ORIGINAL=1 ;;
    B|b) SIDE=B ;;
    A|a) SIDE=A ;;
    *) echo "未知参数: $arg"; echo "用法: $0 [--original] [B]"; exit 1 ;;
  esac
done
export SEAFOX_ORIGINAL
if [ "$SIDE" = "B" ]; then TAPE="tapes/Face B.wav"; export ENTER_AT=4.0
else TAPE="tapes/Face A.wav"; export ENTER_AT=6.5; fi

if [ ! -f "$TAPE" ] || [ ! -f roms/ceci.zip ]; then
  echo "缺少磁带或 ROM，请先运行 ./setup.sh"; exit 1
fi
exec mame ceci -rompath roms -cass "$TAPE" -window -nomaximize -skip_gameinfo \
  -snapshot_directory snap -autoboot_script tools/play_seafox.lua
