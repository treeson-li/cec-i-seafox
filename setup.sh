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
fetch() { # 本地路径 远程文件名 SHA1 [archive.org 条目，默认《海战》]
  if [ -f "$1" ] && [ "$(shasum -a 1 "$1" | cut -d' ' -f1)" = "$3" ]; then
    echo "已有 $1"; return
  fi
  echo "下载 $1 ..."
  curl -fL --retry 3 -o "$1" "${4:-$ITEM}/$2" || { echo "下载失败: $1"; ok=0; return; }
  if [ "$(shasum -a 1 "$1" | cut -d' ' -f1)" != "$3" ]; then echo "校验失败: $1"; ok=0; fi
}
fetch "tapes/Face A.wav" "Face%20A.wav" ab151d913bc4b8d34d01509bd8653c1c963528d2
fetch "tapes/Face B.wav" "Face%20B.wav" 2e7ee3623c6a8aeae21c3429ee88e6b9280c488e
fetch "manual.jpg" "scans/jpegs/manual.jpg" 14125878c97f05750c80ca2cb013e3533eb8e9de
# 《警察抓小偷》(Lode Runner)
LR=https://archive.org/download/jingcha-zhua-xiaotou-lode-runner-zhonghua-xuexi-ji-cec-i-apple-ii-china-tape
mkdir -p tapes/loderunner
fetch "tapes/loderunner/Face A.wav" "Face%20A.wav" 2e73dd8bf735d4bec4642ea7e06f43955f90e59d $LR
fetch "tapes/loderunner/Face B.wav" "Face%20B.wav" 71e771b8197e7085bebb90914acac9bece67e230 $LR

echo "== ROM（需自备，见 README）"
mkdir -p roms
# 缺 ROM 时尝试从私有备份仓库拉取；没有访问权限会静默失败，按 README 自行下载即可
ROM_BACKUP=https://github.com/treeson-li/cec-i-seafox-roms.git
missing=0
for z in ceci a2diskiing d2fdc votrsc01a a2twarp; do [ -f roms/$z.zip ] || missing=1; done
if [ $missing = 1 ]; then
  tmp=$(mktemp -d)
  if GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 "$ROM_BACKUP" "$tmp/r" 2>/dev/null; then
    for z in "$tmp"/r/*.zip; do [ -f "roms/$(basename "$z")" ] || cp "$z" roms/; done
    echo "已从私有备份仓库取得 ROM"
  else
    echo "无法访问私有备份仓库，请按 README 自行下载 ROM 放进 roms/"
  fi
  rm -rf "$tmp"
fi
if command -v mame >/dev/null 2>&1; then
  for set in ceci a2diskiing d2fdc votrsc01a; do
    mame -rompath roms -verifyroms $set 2>&1 | grep -E "romset $set " || { echo "romset $set 缺失"; ok=0; }
  done
  # TransWarp 加速卡 ROM 可选：没有时修改版照常运行，只是后期关卡会变慢
  mame -rompath roms -verifyroms a2twarp 2>&1 | grep -E "romset a2twarp " ||
    echo "romset a2twarp 缺失（可选，用于修改版的 CPU 加速，见 README）"
fi

if [ $ok = 1 ]; then echo; echo "准备完毕，运行 ./play_seafox.sh（海战）或 ./play_loderunner.sh（警察抓小偷）开始游戏"; else echo; echo "还有问题，见上面的提示"; exit 1; fi
