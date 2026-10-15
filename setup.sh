#!/bin/sh
# 准备运行环境：检查 MAME，从 archive.org 下载磁带录音和说明书并校验，检查 ROM。
cd "$(dirname "$0")"
ok=1

echo "== MAME"
if command -v mame >/dev/null 2>&1; then
  mame -version
else
  echo "未找到 mame。macOS: brew install mame；Linux: 用发行版的包；Windows: https://www.mamedev.org/release.html"
  ok=0
fi

echo "== 磁带与说明书（archive.org）"
ITEM=https://archive.org/download/haizhan-seafox-zhonghua-xuexi-ji-cec-i-apple-ii-china-tape
mkdir -p tapes
fetch() { # 本地路径 远程文件名 SHA1
  if [ -f "$1" ] && [ "$(shasum -a 1 "$1" | cut -d' ' -f1)" = "$3" ]; then
    echo "已有 $1"; return
  fi
  echo "下载 $1 ..."
  curl -fL --retry 3 -o "$1" "$ITEM/$2" || { echo "下载失败: $1"; ok=0; return; }
  if [ "$(shasum -a 1 "$1" | cut -d' ' -f1)" != "$3" ]; then echo "校验失败: $1"; ok=0; fi
}
fetch "tapes/Face A.wav" "Face%20A.wav" ab151d913bc4b8d34d01509bd8653c1c963528d2
fetch "tapes/Face B.wav" "Face%20B.wav" 2e7ee3623c6a8aeae21c3429ee88e6b9280c488e
fetch "manual.jpg" "manual.jpg" 14125878c97f05750c80ca2cb013e3533eb8e9de

echo "== ROM（需自备，见 README）"
mkdir -p roms
if command -v mame >/dev/null 2>&1; then
  for set in ceci a2diskiing d2fdc votrsc01a; do
    mame -rompath roms -verifyroms $set 2>&1 | grep -E "romset $set " || { echo "romset $set 缺失"; ok=0; }
  done
fi

if [ $ok = 1 ]; then echo; echo "准备完毕，运行 ./play_seafox.sh 开始游戏"; else echo; echo "还有问题，见上面的提示"; exit 1; fi
