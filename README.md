# 中华学习机 CEC-I《海战 SEAFOX》模拟运行包

在 [MAME](https://www.mamedev.org/) 的 `ceci` 驱动上运行 1988 年陕西省计算机厂发行的磁带游戏《海战》（中华学习机游戏软件 NO.88-018）。脚本自动完成"输命令、放磁带、等装载"，一条命令就能玩。

提供两个版本：

| 版本 | 启动 | 内容 |
|---|---|---|
| 修改版（默认） | `./play_seafox.sh` | 方向键 8 方向操作、新增向左发射和追踪鱼雷、向前发射不限颗数、停船时油耗减半、无限命 |
| 原版 | `./play_seafox.sh --original` | 原按键、原开火限制、原油耗、3 条命，和当年一样 |

两个版本运行的是同一份磁带，修改版通过 MAME 的 Lua 脚本在运行时改变游戏读到的值，不修改游戏代码。

## 快速开始

```sh
git clone https://github.com/treeson-li/cec-i-seafox.git
cd cec-i-seafox
# 1. 按下面"ROM"一节准备好 4 个 ROM 压缩包，放进 roms/
#    （有私有备份仓库访问权限的人可跳过这步，setup.sh 会自动拉取）
# 2. 安装 MAME、下载磁带和说明书、检查 ROM：
./setup.sh
# 3. 开始游戏
./play_seafox.sh              # 修改版，从第 1 关开始
./play_seafox.sh 4            # 修改版，从第 4 关开始（关卡 1-5）
./play_seafox.sh --original   # 原版
./play_seafox.sh --original 5 # 原版，从第 5 关开始
```

装载用的是 A 面磁带。B 面内容相同，是备份，要改用 B 面可以编辑 `play_seafox.sh` 里的 `TAPE`。

装载阶段自动关闭限速，十几秒就能看到标题画面（中华学习机游戏软件 / 海战 SEAFOX / 陕西省计算机厂制作 NO.88-018），之后恢复正常速度进入演示画面，**按空格开始游戏**。

退出：模拟的是带完整键盘的机器，MAME 快捷键默认被屏蔽。先按 Fn+Delete（其他键盘是 Scroll Lock 或 Insert）打开 UI 控制，再按 Esc。

### 需要的东西

| 东西 | 来源 | 由谁准备 |
|---|---|---|
| MAME（测试版本 0.289） | macOS: `brew install mame`；其他系统见 [mamedev.org](https://www.mamedev.org/release.html) | 自己安装，`setup.sh` 会检查 |
| 磁带录音 `tapes/Face A.wav`、`Face B.wav`，说明书 `manual.jpg` | [archive.org 上的原始转录](https://archive.org/details/haizhan-seafox-zhonghua-xuexi-ji-cec-i-apple-ii-china-tape) | `setup.sh` 自动下载并校验 SHA1 |
| ROM | 见下一节 | **自备** |

### ROM

ROM 有版权，本仓库不提供。需要 MAME 0.289 格式的 4 个 ROM 压缩包，放进 `roms/` 目录（不用解压）：

| 压缩包 | 内容 |
|---|---|
| `ceci.zip` | 中华学习机主板 ROM |
| `a2diskiing.zip` | Disk II 控制卡（`ceci` 内置） |
| `d2fdc.zip` | Disk II 软驱控制器 |
| `votrsc01a.zip` | 语音卡 |

MAME 按 SHA1 逐个校验，来源不对或文件损坏会直接报错。`./setup.sh` 会对每个压缩包运行 `mame -verifyroms`，全部显示 `is good` 就可以了。需要的具体文件和校验值：

```
ceci.zip
  u7.alt                        SHA1 ff9673f628390e9b0fb60732acc72b580200b5ae
  u35.alt                       SHA1 db1ed69b2ed3280b1c90f76dbd637370d5bc11b0
  u7.tmm24256ap.bin             SHA1 a2967b3a9a040a1c47eb0fea9a632b833cd1c060
  u35.tmm24256ap.bin            SHA1 f4fd7ceda4c9ab9bc626d6abb76b7fd2b5faf2da
  u7.selftest.bin               SHA1 d2c716d0eb9f1c70e108d16c6a88d44b894e39fd
  u33.mx231024-0059.bin         SHA1 01c787e150bf1378088a9333ec9338387aae0f50
  u34.mx231024-0060.bin         SHA1 dc4cbe19e202d2afb56998ff04255b3171b58e14
  u13.9433c-0202.rcl-zh-32.bin  SHA1 58ad0008df72896a18601e090ee0d58155ffa5be
  u26.9433c-0201.rcl-zh-16.bin  SHA1 7efdf6f4ee0ed01ff06341c601496a43d06afd6b
  u40.m2822.bin                 SHA1 bc39fbd5b9a8d2287ac5d0a42e639fc4d3c2f9d4
a2diskiing.zip
  341-0027-a.p5                 SHA1 d4181c9f046aafc3fb326b381baac809d9e38d16
d2fdc.zip
  341-0028-a.rom                SHA1 bc39fbd5b9a8d2287ac5d0a42e639fc4d3c2f9d4
votrsc01a.zip
  sc01a.bin                     SHA1 1d6da90b1807a01b5e186ef08476119a862b5e6d
```

本项目测试时用的 ROM 下载自 [planetemu.net 的 MAME merged 集合](https://www.planetemu.net/en/rom/mame-roms-merged/ceci)，4 个压缩包都通过了 MAME 0.289 的校验。该站点与本项目无关，ROM 的版权和使用责任由使用者自行承担。

维护者另有一个私有备份仓库 `cec-i-seafox-roms`；被邀请为协作者的人运行 `./setup.sh` 时会自动从那里拉取 ROM，没有权限则跳过。

最正当的来源是从实机转储：`u7`、`u35` 是 27256 EPROM，普通编程器就能读；`u33`、`u34` 是 128KB 掩膜 ROM，需要转接座。

## 操作

### 修改版

| 键 | 动作 |
|---|---|
| 空格 | 在标题/演示画面：开始游戏；游戏中：向上发射 |
| F | 向右发射 |
| D | 向左发射（新增，原版没有） |
| G | 发追踪鱼雷（新增，第 4 关起，见下） |
| 回车 | 暂停 / 继续 |
| ↑ ↓ ← → | 移动，按住走、松开停 |
| 同时按两个方向键 | 斜向移动，例如 ← + ↑ 为左上 |

空格、F、D 按住都会连发。Z（向右）、X（向上）是备用键。原版的方向字母键（U/I/K/,/M/N/H/Y/J）照样能用；D 在原版里是向上发射，修改版改成了向左。

### 原版（说明书上的按键）

| 键 | 动作 |
|---|---|
| U / M / H / K | 上 / 下 / 左 / 右 |
| Y / I / N / , | 左上 / 右上 / 左下 / 右下（说明书上写的是 L，游戏实际用逗号） |
| J | 停船 |
| D / F | 向上开火 / 向前开火 |
| Ctrl-S | 声音开关 |
| Esc | 暂停（再按任意键继续） |

原版的方向是"锁存"的：按一下就一直朝那个方向走，按 J 才停。

## 修改版改了什么

| 项目 | 原版 | 修改版 | 调整方法 |
|---|---|---|---|
| 操作 | 字母键，按一下锁定方向 | 方向键，按住走、松开停，可斜向 | — |
| 向左发射 | 没有 | D 键，鱼雷图形左右镜像 | — |
| 追踪鱼雷 | 没有 | G 键，第 4 关起，追我方右侧的敌潜艇 | — |
| 向前（向右）发射 | 同屏 1 颗 | 不限（对象表快满时暂停开火，防止内存越界） | `SEAFOX_MAX_FWD=1` 恢复原版 |
| 向上发射 | 同屏 1 颗 | 同屏 1 颗 | `SEAFOX_MAX_UP=2` 放宽，**每多 1 颗游戏速度减半** |
| 油耗 | 不管动不动都一样 | 停船时减半 | `SEAFOX_IDLE_FUEL=10` 恢复原版，数值越小越省油 |
| 命数 | 3 条 | 无限（始终显示 3 条） | `SEAFOX_INFINITE_LIVES=0` 恢复原版 |

调整方法是在启动命令前加环境变量，例如 `SEAFOX_MAX_UP=2 ./play_seafox.sh`。

**追踪鱼雷**：从第 4 关（敌潜艇开始放磁性炸弹的那一关）起才能用，第 1~3 关按 G 无效。绿色，和普通鱼雷颜色不同。按 G 向右发射，之后每个节拍在我方潜艇右侧的敌潜艇里找离鱼雷最近的一艘，左右每节拍 6 像素（普通鱼雷 4）、上下每节拍 2 像素朝它去，目标跑到鱼雷身后会掉头。我方右侧没有敌潜艇就直线飞；追约 400 个节拍还没打中也改为直线飞出屏幕。只追敌潜艇，磁性炸弹、瞄准弹、水面上的目标舰和加油船都不追，不过途中撞上的照样会被炸掉。同屏只能有 1 枚，已有一枚在飞时按键无效；每发扣 2 发弹药，只剩 1 发时发不出。

**为什么向上发射不放开**：游戏没有定时器，速度完全取决于 CPU 能不能及时算完每一帧。每颗向上的炮弹都拖着一条要重绘的尾迹，同屏 1/2/3 颗时游戏分别是每秒约 45/22/12 个节拍。向前的炮弹开销很小，同屏 12 颗左右仍有每秒约 30 个节拍。后期关卡东西多时变慢也是同一个原因，和当年实机上一样。

## 文件

```
play_seafox.sh             启动脚本（--original 原版，数字 1-5 指定起始关卡）
setup.sh                   检查 MAME、下载磁带和说明书、检查 ROM
tools/play_seafox.lua      自动装载：输入读带命令、放带、装完后恢复正常速度
tools/seafox_controls.lua  修改版：方向键控制层
tools/seafox_patches.lua   修改版：开火限制、油耗、无限命
tools/seafox_torpedoes.lua 修改版：向左发射、追踪鱼雷
tools/research/            磁带解码和程序分析用的脚本（玩游戏不需要）
docs/TECHNICAL.md          磁带格式、装载过程、游戏内部变量
tapes/submissionInfos.txt  archive.org 上磁带转录的说明
```

## 说明

- 测试环境：macOS，MAME 0.289。脚本用到 MAME 的 Lua 接口，版本差太多时可能需要调整。
- 磁带录音和说明书来自 archive.org 上的转录，版权归原作者所有。
- 磁带格式和游戏内部的分析见 [docs/TECHNICAL.md](docs/TECHNICAL.md)。
