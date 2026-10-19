# 中华学习机 CEC-I《海战 SEAFOX》模拟运行包

在 [MAME](https://www.mamedev.org/) 的 `ceci` 驱动上运行 1988 年陕西省计算机厂发行的磁带游戏《海战》（中华学习机游戏软件 NO.88-018）。脚本自动完成"输命令、放磁带、等装载"，一条命令就能玩。

提供两个版本：

| 版本 | 启动 | 内容 |
|---|---|---|
| 修改版（默认） | `./play_seafox.sh` | 方向键 8 方向操作、新增向左发射和追踪鱼雷、向前发射不限颗数、停船时油耗减半、潜艇航速提高 50%、无限命、速度恒定（后期不再变慢） |
| 原版 | `./play_seafox.sh --original` | 原按键、原开火限制、原油耗、3 条命，和当年一样 |

两个版本运行的是同一份磁带，修改版通过 MAME 的 Lua 脚本在运行时改变游戏读到的值，不修改游戏代码。修改版还会在模拟的机器上插一块 TransWarp 加速卡（需要可选的 `a2twarp.zip`，见"ROM"一节）。

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

**怎样过关**：每关要击沉 10 艘"军火船"，就是水面上最上面（最远）那一排的船。中间一排带白十字的蓝船是医用船，打不沉，向上的炮弹打中会弹回来；最下面贴着水线的紫色船和水下的敌潜艇能打沉、有分，但不算过关。下面两排的船会挡住打上排的炮弹，要等空当再打。

窗口启动时尽量放大到整个屏幕（`-maximize`），可以拖边角改小。

退出：模拟的是带完整键盘的机器，MAME 快捷键默认被屏蔽。先按 Fn+Delete（其他键盘是 Scroll Lock 或 Insert）打开 UI 控制，再按 Esc。

### 需要的东西

| 东西 | 来源 | 由谁准备 |
|---|---|---|
| MAME（测试版本 0.289） | macOS: `brew install mame`；其他系统见 [mamedev.org](https://www.mamedev.org/release.html) | 自己安装，`setup.sh` 会检查 |
| 磁带录音 `tapes/Face A.wav`、`Face B.wav`，说明书 `manual.jpg` | [archive.org 上的原始转录](https://archive.org/details/haizhan-seafox-zhonghua-xuexi-ji-cec-i-apple-ii-china-tape) | `setup.sh` 自动下载并校验 SHA1 |
| 《警察抓小偷》磁带录音 `tapes/loderunner/Face A.wav`、`Face B.wav` | [archive.org 上的原始转录](https://archive.org/details/jingcha-zhua-xiaotou-lode-runner-zhonghua-xuexi-ji-cec-i-apple-ii-china-tape) | `setup.sh` 自动下载并校验 SHA1 |
| ROM | 见下一节 | **自备** |

### ROM

ROM 有版权，本仓库不提供。需要 MAME 0.289 格式的 4 个 ROM 压缩包，放进 `roms/` 目录（不用解压）：

| 压缩包 | 内容 |
|---|---|
| `ceci.zip` | 中华学习机主板 ROM |
| `a2diskiing.zip` | Disk II 控制卡（`ceci` 内置） |
| `d2fdc.zip` | Disk II 软驱控制器 |
| `votrsc01a.zip` | 语音卡 |
| `a2twarp.zip` | （可选）Applied Engineering TransWarp 加速卡，修改版用来让后期关卡不变慢；没有也能玩 |

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
a2twarp.zip（可选）
  ae transwarp rom v1.4.bin     SHA1 7b75534e7895e04859a0b1337801c6eeb0cef52a
```

本项目测试时用的 ROM 下载自 [planetemu.net 的 MAME merged 集合](https://www.planetemu.net/en/rom/mame-roms-merged/ceci)（[a2twarp](https://www.planetemu.net/en/rom/mame-roms-merged/a2twarp) 也在那里），压缩包都通过了 MAME 0.289 的校验。该站点与本项目无关，ROM 的版权和使用责任由使用者自行承担。

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

空格、F、D 按住都会连发；向上发射（空格）两发之间至少隔 1 秒，按一下只发一发。Z（向右）、X（向上）是备用键。原版的方向字母键（U/I/K/,/M/N/H/Y/J）照样能用；D 在原版里是向上发射，修改版改成了向左。

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
| 向上发射 | 同屏 1 颗 | 同屏 3 颗（没有 `a2twarp.zip` 时 1 颗），每秒最多发 1 发 | `SEAFOX_MAX_UP=颗数`，`SEAFOX_UP_INTERVAL=秒数` |
| 油耗 | 不管动不动都一样 | 停船时减半 | `SEAFOX_IDLE_FUEL=10` 恢复原版，数值越小越省油 |
| 潜艇航速 | 每节拍 2 像素 | 每节拍 3 像素（快 50%） | `SEAFOX_SUB_SPEED=倍数`，1 恢复原版 |
| 命数 | 3 条 | 无限（始终显示 3 条） | `SEAFOX_INFINITE_LIVES=0` 恢复原版 |
| 速度 | 东西少时快、多时慢（第 1 关每秒约 29~54 拍，第 5 关最慢约 5 拍） | 固定每秒 17.5 拍（原版第 1 关的一半左右），后期也不变慢（需要 `a2twarp.zip`） | `SEAFOX_TICK_RATE=拍数`，0 为原版不限速；`SEAFOX_ACCEL=0` 不插加速卡 |

调整方法是在启动命令前加环境变量，例如 `SEAFOX_MAX_UP=2 ./play_seafox.sh`。

**追踪鱼雷**：从第 4 关（敌潜艇开始放磁性炸弹的那一关）起才能用，第 1~3 关按 G 无效。绿色，和普通鱼雷颜色不同。按 G 向右发射，发射后锁定一艘"能迎上去打"的敌潜艇：在我方潜艇右侧、在鱼雷前方至少 40 像素，而且照双方当前速度，鱼雷在和它横向相遇前来得及把上下对准；符合的里面挑离鱼雷最近的。太近或高度差太多、来不及对准的不选，免得刚锁定就交错而过、只能掉头。当时没有符合的就先直线飞，等第一艘符合的出现。锁定后只追这一艘，不换目标；追不上就一直追这一艘；目标被别的东西击毁或开出屏幕，鱼雷也不改追别的，而是飞到目标最后出现的位置，然后保持方向直线飞出屏幕。追踪时左右最快每节拍 6 像素（普通鱼雷 4）、上下每节拍 2 像素朝它去。目标跑到鱼雷身后会掉头，但不是瞬间反向：左右速度每节拍最多变化 1 像素（固定加速度），要先减速再反向加速，大约 12 个节拍掉过头来，会多冲出去一段，画出一道弧线。掉头时离右边太近，可能先冲出屏幕而消失。加速度可以用 `SEAFOX_HOMING_ACCEL` 调，数值越小转弯越大。没有目标时直线飞；追约 400 个节拍还没打中也改为直线飞出屏幕。只追敌潜艇，磁性炸弹、瞄准弹、水面上的目标舰和加油船都不追，不过途中撞上的照样会被炸掉。同屏只能有 1 枚，已有一枚在飞时按键无效；每发扣 2 发弹药，只剩 1 发时发不出。

**速度**：原游戏没有定时器，主循环一圈就是一个节拍，跑完马上开始下一圈，所以东西少时快、东西多时慢，当年实机上就是这样。修改版做了两件事：一是节拍器，每拍至少间隔 1/17.5 秒，东西少时不再变快；二是插 TransWarp 加速卡，CPU 从 1.02 MHz 提到约 3.58 MHz，东西多时也算得完。实测第 5 关 99% 的节拍在 36 毫秒以内（未加速时 35% 的节拍慢于每秒 30 拍，最慢一拍 123 毫秒）。装磁带和发声时卡自动降回 1 MHz：读带程序靠数 CPU 周期量信号，扬声器的音调由延时循环决定，加速会读错带、让音调变高。没有 `a2twarp.zip` 时只有节拍器，后期仍会变慢。

**向上发射的颗数**：每颗向上的炮弹都拖着一条要重绘的尾迹，很费 CPU。未加速时同屏 1/2/3 颗分别是每秒约 45/22/12 个节拍，所以没有加速卡时默认只放 1 颗；插了加速卡后 3 颗也能保持每秒约 28 拍以上，默认 3 颗。向前的炮弹开销很小，不受影响。

## 另一个游戏：警察抓小偷（Lode Runner）

成都三开元电脑经营部 1988 年发行的磁带版 *Lode Runner*（标题画面写着"警察抓小偷 (LODE RUNNER 九)"），没有修改。

```sh
./play_loderunner.sh
```

装载阶段同样关闭限速，十几秒后出现中文标题画面，"HIT ANY KEY TO BEGIN" 时按任意键开始；之后是演示画面，再按一下键进入第一关，每关开始（和每次死后）也要按一下键才动。

| 按键 | 作用 |
|---|---|
| 方向键 | 移动、爬梯子、攀绳；按住走，松开站住 |
| Z / X（或 U / O） | 向左 / 向右挖洞 |
| Esc | 暂停，再按 Esc 继续 |
| Ctrl-A | 放弃这条命（被困住时用） |
| Ctrl-R | 结束这一局 |
| Ctrl-S | 声音开关 |
| Ctrl-H / Ctrl-U | 游戏变慢 / 变快 |

原版的方向键是 I/J/K/L，按一下就一直往那个方向走，按空格才停，现在也还能用。电脑方向键在模拟键盘上本来是 Ctrl-H/U/K/J，会改游戏速度、切到摇杆模式，所以 `tools/loderunner_controls.lua` 把它们换成了"按住走、松开停"的 I/J/K/L。

原始录音的波形上下不对称，CEC-I ROM 的读带例程在 MAME 里对不准同步位，直接放原录音装不进去。所以第一次运行时会先用 `tools/loderunner_tape.py` 把两面录音解码（三条记录按 SHA1 校验，A 面第三条有坏块，取 B 面的），再合成一盘干净的标准磁带 `tapes/loderunner/clean.wav`。格式和装载过程见 [docs/TECHNICAL.md](docs/TECHNICAL.md) 第 6 节。

## 文件

```
play_seafox.sh             启动脚本（--original 原版，数字 1-5 指定起始关卡）
setup.sh                   检查 MAME、下载磁带和说明书、检查 ROM
tools/play_seafox.lua      自动装载：输入读带命令、放带、装完后恢复正常速度
tools/seafox_controls.lua  修改版：方向键控制层
tools/seafox_patches.lua   修改版：开火限制、油耗、无限命、航速
tools/seafox_torpedoes.lua 修改版：向左发射、追踪鱼雷
tools/seafox_speed.lua     修改版：节拍器，固定节拍速度
tools/seafox_accel.lua     修改版：TransWarp 加速卡的开关（装带、发声时降速）
tools/research/            磁带解码和程序分析用的脚本（玩游戏不需要）
docs/TECHNICAL.md          磁带格式、装载过程、游戏内部变量
tapes/submissionInfos.txt  archive.org 上磁带转录的说明
play_loderunner.sh         《警察抓小偷》启动脚本
tools/play_loderunner.lua  《警察抓小偷》自动装载
tools/loderunner_controls.lua 《警察抓小偷》方向键控制层
tools/loderunner_tape.py   《警察抓小偷》磁带解码与合成
tapes/loderunner/          《警察抓小偷》磁带（录音由 setup.sh 下载，clean.wav 自动生成）
```

## 说明

- 测试环境：macOS，MAME 0.289。脚本用到 MAME 的 Lua 接口，版本差太多时可能需要调整。
- 磁带录音和说明书来自 archive.org 上的转录，版权归原作者所有。
- 磁带格式和游戏内部的分析见 [docs/TECHNICAL.md](docs/TECHNICAL.md)。
