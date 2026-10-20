#!/bin/sh
# 准备运行环境：检查 MAME，从 archive.org 下载磁带录音和说明书并校验，检查 ROM。
# archive.org 下载不到的磁带、缺的 ROM 尝试从私有备份仓库拉取（需要访问权限）。
cd "$(dirname "$0")"
ok=1

echo "== MAME"
if command -v mame >/dev/null 2>&1; then
  mame -version
else
  echo "未找到 mame。macOS: brew install mame；Linux: 用发行版的包；Windows: https://www.mamedev.org/release.html"
  ok=0
fi

# 私有备份仓库：ROM、《海战》A 面录音、《警察抓小偷》合成好的 clean.wav。没有访问权限时静默跳过
BACKUP=https://github.com/treeson-li/cec-i-seafox-roms.git
backup_dir=""
backup() { # 克隆一次，成功时 backup_dir 为仓库目录
  [ -n "$backup_dir" ] && return 0
  tmp=$(mktemp -d)
  if GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 "$BACKUP" "$tmp/r" 2>/dev/null; then backup_dir="$tmp/r"; return 0; fi
  rm -rf "$tmp"; return 1
}
sha1() { shasum -a 1 "$1" | cut -d' ' -f1; }
from_backup() { # 本地路径 SHA1：从备份仓库的同名路径复制
  backup || return 1
  [ -f "$backup_dir/$1" ] && [ "$(sha1 "$backup_dir/$1")" = "$2" ] || return 1
  cp "$backup_dir/$1" "$1" && echo "已从私有备份仓库取得 $1"
}

echo "== 磁带与说明书（archive.org）"
fetch() { # 本地路径 远程文件名 SHA1 archive.org 条目；失败返回 1
  if [ -f "$1" ] && [ "$(sha1 "$1")" = "$3" ]; then
    echo "已有 $1"; return 0
  fi
  echo "下载 $1 ..."
  curl -fL --retry 3 -o "$1" "$4/$2" || { echo "下载失败: $1"; rm -f "$1"; return 1; }
  if [ "$(sha1 "$1")" != "$3" ]; then echo "校验失败: $1"; rm -f "$1"; return 1; fi
}
# 《海战》：两面内容相同，只用 A 面；B 面是备份，下载不到不影响
SF=https://archive.org/download/haizhan-seafox-zhonghua-xuexi-ji-cec-i-apple-ii-china-tape
SF_A=ab151d913bc4b8d34d01509bd8653c1c963528d2
mkdir -p tapes/seafox
fetch "tapes/seafox/Face A.wav" "Face%20A.wav" $SF_A $SF ||
  from_backup "tapes/seafox/Face A.wav" $SF_A || ok=0
fetch "tapes/seafox/Face B.wav" "Face%20B.wav" 2e7ee3623c6a8aeae21c3429ee88e6b9280c488e $SF
fetch "manual.jpg" "scans/jpegs/manual.jpg" 14125878c97f05750c80ca2cb013e3533eb8e9de $SF
# 《警察抓小偷》(Lode Runner)：A 面第三条记录有坏块、B 面第二条错了一位，要两面一起解码合成 clean.wav（play_loderunner.sh 第一次运行时做）；
# 已有 clean.wav 就不需要原录音。下载不到时直接取备份仓库里合成好的 clean.wav
LR=https://archive.org/download/jingcha-zhua-xiaotou-lode-runner-zhonghua-xuexi-ji-cec-i-apple-ii-china-tape
LR_CLEAN=aa63ff5995472b39caf37976203bf9c766c42faf
mkdir -p tapes/loderunner
if [ -f tapes/loderunner/clean.wav ] && [ "$(sha1 tapes/loderunner/clean.wav)" = $LR_CLEAN ]; then
  echo "已有 tapes/loderunner/clean.wav"
else
  { fetch "tapes/loderunner/Face A.wav" "Face%20A.wav" 2e73dd8bf735d4bec4642ea7e06f43955f90e59d $LR &&
    fetch "tapes/loderunner/Face B.wav" "Face%20B.wav" 71e771b8197e7085bebb90914acac9bece67e230 $LR; } ||
    from_backup tapes/loderunner/clean.wav $LR_CLEAN || ok=0
fi

echo "== ROM（请按 README 给出的网址下载）"
mkdir -p roms
missing=0
for z in ceci a2diskiing d2fdc votrsc01a a2twarp; do [ -f roms/$z.zip ] || missing=1; done
if [ $missing = 1 ]; then
  if backup; then
    for z in "$backup_dir"/*.zip; do [ -f "roms/$(basename "$z")" ] || cp "$z" roms/; done
    echo "已从私有备份仓库取得 ROM"
  else
    echo "无法访问私有备份仓库，请从 README 给出的网址下载 ROM 放进 roms/"
  fi
fi
[ -n "$backup_dir" ] && rm -rf "$(dirname "$backup_dir")"
if command -v mame >/dev/null 2>&1; then
  for set in ceci a2diskiing d2fdc votrsc01a; do
    mame -rompath roms -verifyroms $set 2>&1 | grep -E "romset $set " || { echo "romset $set 缺失"; ok=0; }
  done
  # TransWarp 加速卡 ROM 可选：没有时修改版照常运行，只是后期关卡会变慢
  mame -rompath roms -verifyroms a2twarp 2>&1 | grep -E "romset a2twarp " ||
    echo "romset a2twarp 缺失（可选，用于修改版的 CPU 加速，见 README）"
fi

if [ $ok = 1 ]; then echo; echo "准备完毕，运行 ./play_seafox.sh（海战）或 ./play_loderunner.sh（警察抓小偷）开始游戏"; else
  echo; echo "还有问题，见上面的提示"
  echo "如果是下载地址失效，请到这里留言说明缺哪个文件：https://github.com/treeson-li/cec-i-seafox/issues"
  exit 1
fi
