#!/bin/sh
# 用法: ./play_loderunner.sh
# 《警察抓小偷》(Lode Runner，成都三开元电脑经营部，1988)。装载约 3 分钟（关闭限速时只要十几秒）。
# 标题画面按任意键开始，演示画面和每关开始时再按一下键。
# 方向键移动（按住走、松开停），Z/X（或 U/O）向左/向右挖洞，Esc 暂停，Ctrl-A 放弃这条命，
#   Ctrl-R 结束这一局，Ctrl-S 声音开关，Ctrl-H/Ctrl-U 变慢/变快。
# 退出：先按 Fn+Delete（MAME 的 UI 切换键）再按 Esc。
cd "$(dirname "$0")"
DIR=tapes/loderunner
TAPE="$DIR/clean.wav"
if [ ! -f roms/ceci.zip ] || { [ ! -f "$TAPE" ] && { [ ! -f "$DIR/Face A.wav" ] || [ ! -f "$DIR/Face B.wav" ]; }; }; then
  echo "缺少磁带或 ROM，请先运行 ./setup.sh"; exit 1
fi
# 原录音在 MAME 里读不准，先解码再合成一盘干净的磁带（只做一次）
if [ ! -f "$TAPE" ]; then
  python3 tools/loderunner_tape.py "$DIR/Face A.wav" "$DIR/Face B.wav" "$TAPE" || exit 1
fi
exec mame ceci -rompath roms -cass "$TAPE" -window -maximize -skip_gameinfo \
  -snapshot_directory snap -autoboot_script tools/play_loderunner.lua
