---
title: 中华学习机 CEC-I 磁带游戏《警察抓小偷》Lode Runner 模拟器一键运行
description: 在 MAME 模拟器上运行中华学习机 CEC-I 的磁带游戏《警察抓小偷》（Lode Runner，1988 年成都三开元电脑经营部发行），自动装载磁带，方向键操作。Chinese cassette Lode Runner for the CEC-I.
---

# 中华学习机 CEC-I《警察抓小偷》Lode Runner 磁带游戏

1988 年成都三开元电脑经营部发行的中华学习机 CEC-I 磁带游戏《警察抓小偷》（标题画面写着"警察抓小偷 (LODE RUNNER 九)"），在 [MAME](https://www.mamedev.org/) 模拟器的 `ceci` 驱动上一条命令就能玩。脚本自动输入读带命令、放磁带、等装载完成，不用自己操作 Monitor 或 BASIC。游戏本身没有修改。

中华学习机 CEC-I 是 80 年代末国内学校里常见的 Apple II 兼容机，当年的游戏大多用录音磁带装载。这盘磁带的录音保存在 [archive.org](https://archive.org/details/jingcha-zhua-xiaotou-lode-runner-zhonghua-xuexi-ji-cec-i-apple-ii-china-tape) 上。

代码在 GitHub 仓库 [treeson-li/cec-i-seafox](https://github.com/treeson-li/cec-i-seafox)，同一个仓库里还有另一盘中华学习机磁带游戏《海战 SEAFOX》。

## 怎么运行

```sh
git clone https://github.com/treeson-li/cec-i-seafox.git
cd cec-i-seafox
./setup.sh            # 检查 MAME、从 archive.org 下载磁带录音、检查 ROM
./play_loderunner.sh  # 开始游戏
```

需要准备：

- **MAME**（测试版本 0.289）：macOS 用 `brew install mame`，其他系统见 [mamedev.org](https://www.mamedev.org/release.html)。
- **中华学习机的 ROM**：有版权，仓库里不附带，请到 [planetemu.net 的 MAME merged 集合](https://www.planetemu.net/en/rom/mame-roms-merged/ceci) 下载 `ceci.zip` 等压缩包，放进 `roms/`。文件清单和 SHA1 校验值见仓库 [README 的"ROM"一节](https://github.com/treeson-li/cec-i-seafox#rom)。

磁带录音或 ROM 下载不到时，请到 [GitHub Issues 留言](https://github.com/treeson-li/cec-i-seafox/issues/new?title=%E4%B8%8B%E8%BD%BD%E5%A4%B1%E6%95%88%EF%BC%9A)，写明缺哪个文件。

## 怎么玩

装载时自动关闭限速，十几秒后出现中文标题画面。出现 "HIT ANY KEY TO BEGIN" 时按任意键开始；之后是演示画面，再按一下键进入第一关。每关开始（和每次死后）也要按一下键才会动。

| 按键 | 作用 |
|---|---|
| 方向键 | 移动、爬梯子、攀绳；按住走，松开站住 |
| Z / X（或 U / O） | 向左 / 向右挖洞 |
| Esc | 暂停，再按 Esc 继续 |
| Ctrl-A | 放弃这条命（被困住时用） |
| Ctrl-R | 结束这一局 |
| Ctrl-S | 声音开关 |
| Ctrl-H / Ctrl-U | 游戏变慢 / 变快 |

原版的方向键是 I/J/K/L：按一下就一直往那个方向走，按空格才停，现在也还能用。电脑的方向键在模拟的中华学习机键盘上本来是 Ctrl-H/U/K/J，会改游戏速度、切到摇杆模式，所以脚本把它们换成了"按住走、松开停"。

退出：先按 Fn+Delete（其他键盘是 Scroll Lock 或 Insert）打开 MAME 的 UI 控制，再按 Esc。

## 为什么不直接放原始录音

**原始录音不能直接用**，有两个问题：

- 波形上下不对称，中华学习机 ROM 里的读带程序在 MAME 里对不准同步位，直接放原录音装不进去。
- 两面都有损坏，单独哪一面都不完整。磁带上有三条记录：A 面第三条（游戏本体）有 12 个坏块；B 面第二条（标题画面）错了一位，而且这个错误恰好通过了块校验，读带时发现不了。

所以第一次运行时，`tools/loderunner_tape.py` 会把两面录音都解码，每条记录按已知的 SHA1 挑出完好的一份（第一条两面相同，第二条取 A 面，第三条取 B 面），再合成一盘干净的标准磁带 `tapes/loderunner/clean.wav`，实际玩的是这盘合成磁带。磁带格式和装载过程的详细分析见 [TECHNICAL.md 第 6 节](https://github.com/treeson-li/cec-i-seafox/blob/main/docs/TECHNICAL.md#6-警察抓小偷lode-runner)。
