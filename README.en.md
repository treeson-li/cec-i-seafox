# Sea Fox (海战) on the CEC-I / Zhonghua Xuexiji, emulated in MAME

[中文](README.md) | English

Run the 1988 cassette game *Sea Fox* (海战, "China Education Computer game software NO.88-018", published by Shaanxi Computer Factory 陕西省计算机厂) on the [MAME](https://www.mamedev.org/) `ceci` driver. The CEC-I (中华学习机 CEC-I, China Education Computer) is a Chinese Apple II compatible from the late 1980s. *Sea Fox* was originally a 1982 Broderbund game for the Apple II; this is the Chinese cassette release. The scripts type the load command, play the tape and wait for the load, so the game starts with a single command.

Two versions are provided:

| Version | Command | What you get |
|---|---|---|
| Modded (default) | `./play_seafox.sh` | 8-way arrow-key control, new left-firing and homing torpedoes, unlimited forward shots, half fuel use while stopped, double submarine speed (as fast as enemy subs), infinite lives, constant game speed (later levels no longer slow down) |
| Original | `./play_seafox.sh --original` | Original keys, firing limits, fuel use and 3 lives, as in 1988 |

Both versions load the same tape. The modded version uses MAME Lua scripts to change the values the game reads at run time; the game code itself is not patched. It also plugs an emulated TransWarp accelerator card into the machine (needs the optional `a2twarp.zip`, see [ROMs](#roms)).

A second game is included: the cassette release of *Lode Runner* (警察抓小偷), see [below](#second-game-lode-runner-警察抓小偷).

## Quick start

```sh
git clone https://github.com/treeson-li/cec-i-seafox.git
cd cec-i-seafox
# 1. Put the ROM zips into roms/ (see "ROMs" below)
# 2. Check MAME, download the tapes and manual, verify the ROMs:
./setup.sh
# 3. Play
./play_seafox.sh              # modded, from level 1
./play_seafox.sh 4            # modded, from level 4 (levels 1-5)
./play_seafox.sh --original   # original
./play_seafox.sh --original 5 # original, from level 5
```

Side A of the tape is used. Side B has the same content as a backup; to use it, edit `TAPE` in `play_seafox.sh`.

Throttling is turned off while the tape loads, so the title screen (中华学习机游戏软件 / 海战 SEAFOX / 陕西省计算机厂制作 NO.88-018) appears within a few seconds. Normal speed then resumes and the demo starts. **Press Space to start the game.**

**How to clear a level**: sink the 10 ammunition ships, the top (farthest) row of ships on the surface. The middle row, blue ships with a white cross, are hospital ships: they can't be sunk and upward shots bounce off them. The purple ships at the waterline and the enemy submarines can be sunk for points but don't count toward clearing the level. The two lower rows block shots aimed at the top row, so wait for a gap.

The window opens maximized (`-maximize`); drag a corner to make it smaller.

To quit: the emulated machine has a full keyboard, so MAME's hotkeys are disabled by default. Press Fn+Delete (Scroll Lock or Insert on other keyboards) to enable UI controls, then Esc.

### Requirements

| Item | Source | Who provides it |
|---|---|---|
| MAME (tested with 0.289) | macOS: `brew install mame`; other systems: [mamedev.org](https://www.mamedev.org/release.html) | You; `setup.sh` checks for it |
| Tape recordings `tapes/seafox/Face A.wav`, `Face B.wav` and manual `manual.jpg` | [Original transfer on archive.org](https://archive.org/details/haizhan-seafox-zhonghua-xuexi-ji-cec-i-apple-ii-china-tape) | Downloaded by `setup.sh`, SHA1-checked |
| *Lode Runner* tape recordings `tapes/loderunner/Face A.wav`, `Face B.wav` | [Original transfer on archive.org](https://archive.org/details/jingcha-zhua-xiaotou-lode-runner-zhonghua-xuexi-ji-cec-i-apple-ii-china-tape) | Downloaded by `setup.sh`, SHA1-checked |
| ROMs | See next section | **You** |

### ROMs

The ROMs are copyrighted and not included. You need these MAME 0.289 ROM sets in `roms/` (keep them zipped):

| Zip | Contents |
|---|---|
| `ceci.zip` | CEC-I mainboard ROMs |
| `a2diskiing.zip` | Disk II controller card (built into `ceci`) |
| `d2fdc.zip` | Disk II floppy controller |
| `votrsc01a.zip` | Speech card |
| `a2twarp.zip` | (Optional) Applied Engineering TransWarp accelerator, used by the modded version to keep later levels at full speed; the game runs without it |

MAME checks every file by SHA1 and refuses bad or mismatched files. `./setup.sh` runs `mame -verifyroms` on each set; you're ready when they all report `is good`. Required files and checksums:

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
a2twarp.zip (optional)
  ae transwarp rom v1.4.bin     SHA1 7b75534e7895e04859a0b1337801c6eeb0cef52a
```

The ROMs used for testing came from the [MAME merged set on planetemu.net](https://www.planetemu.net/en/rom/mame-roms-merged/ceci) ([a2twarp](https://www.planetemu.net/en/rom/mame-roms-merged/a2twarp) is there too); all passed MAME 0.289 verification. That site is not affiliated with this project, and you are responsible for the copyright status of any ROMs you use.

The maintainer keeps a private backup repository, `cec-i-seafox-roms`, holding the ROMs, side A of the Sea Fox tape and the re-encoded Lode Runner `clean.wav`. For invited collaborators, `./setup.sh` fetches from it when ROMs are missing or a tape can't be downloaded from archive.org; for everyone else this step is skipped.

The most legitimate source is dumping a real machine: `u7` and `u35` are 27256 EPROMs readable with an ordinary programmer; `u33` and `u34` are 128 KB mask ROMs that need an adapter.

### If a download is broken

If the archive.org tape recordings or manual, or the ROM sources above, stop working, please [open an issue](https://github.com/treeson-li/cec-i-seafox/issues/new?title=Download%20broken%3A%20) saying which file is missing and what `./setup.sh` printed. The maintainer keeps backups and will reply.

## Controls

### Modded version

| Key | Action |
|---|---|
| Space | On the title/demo screen: start the game; in game: fire upward |
| F | Fire right |
| D | Fire left (new) |
| G | Homing torpedo (new, from level 4, see below) |
| Enter | Pause / resume |
| ↑ ↓ ← → | Move while held, stop when released |
| Two arrow keys together | Diagonal, e.g. ← + ↑ for up-left |

Space, F and D auto-repeat while held. Upward shots are at least 1 second apart, so a single press fires once. Z (right) and X (up) are alternates. The original direction letters (U/I/K/,/M/N/H/Y/J) still work; D, which fired upward in the original, now fires left.

### Original version (keys from the manual)

| Key | Action |
|---|---|
| U / M / H / K | Up / down / left / right |
| Y / I / N / , | Up-left / up-right / down-left / down-right (the manual says L; the game actually uses comma) |
| J | Stop |
| D / F | Fire up / fire forward |
| Ctrl-S | Sound on/off |
| Esc | Pause (any key resumes) |

Directions in the original latch: one press keeps the sub moving that way until you press J.

## What the modded version changes

| Item | Original | Modded | How to adjust |
|---|---|---|---|
| Controls | Letter keys, one press latches a direction | Arrow keys, move while held, diagonals | — |
| Fire left | None | D, with a mirrored torpedo sprite | — |
| Homing torpedo | None | G, from level 4, chases enemy subs to your right | — |
| Forward (right) shots | 1 on screen | Unlimited (firing pauses when the object table is nearly full, to avoid overrunning memory) | `SEAFOX_MAX_FWD=1` restores the original |
| Upward shots | 1 on screen | 3 on screen (1 without `a2twarp.zip`), at most 1 per second | `SEAFOX_MAX_UP=count`, `SEAFOX_UP_INTERVAL=seconds` |
| Fuel use | Same whether moving or not | Halved while stopped | `SEAFOX_IDLE_FUEL=10` restores the original; lower uses less fuel |
| Submarine speed | 2 pixels every 2 ticks, half the speed of enemy subs (2 pixels per tick) | 4 pixels every 2 ticks, as fast as enemy subs | `SEAFOX_SUB_SPEED=multiplier`, 1 restores the original |
| Lives | 3 | Infinite (always shows 3) | `SEAFOX_INFINITE_LIVES=0` restores the original |
| Game speed | Fast with few objects, slow with many (level 1 about 29–54 ticks/s, level 5 as slow as about 5) | Fixed 17.5 ticks/s (about half of original level 1), no slowdown later (needs `a2twarp.zip`) | `SEAFOX_TICK_RATE=ticks`, 0 for the original unthrottled loop; `SEAFOX_ACCEL=0` leaves out the accelerator card |

Set these as environment variables before the command, e.g. `SEAFOX_MAX_UP=2 ./play_seafox.sh`.

**Homing torpedo**: available from level 4 (the level where enemy subs start dropping magnetic mines); G does nothing on levels 1–3. It is green, unlike ordinary torpedoes. G fires it to the right, and it locks onto one enemy sub it can meet head-on: to the right of your sub, at least 40 pixels ahead of the torpedo, and far enough away that, at current speeds, the torpedo can line up vertically before they pass. Among those it picks the nearest. Targets too close or too far off vertically are skipped, so the torpedo doesn't lock on and then immediately fly past and have to turn around. If none qualify it flies straight until one does. Once locked it never switches targets; if the target is destroyed by something else or leaves the screen, the torpedo flies to its last position and then straight off screen. While chasing it moves up to 6 pixels per tick horizontally (ordinary torpedoes move 4) and 2 pixels per tick vertically. If the target gets behind it, it turns around with a fixed acceleration of at most 1 pixel per tick per tick, taking about 12 ticks and overshooting in an arc; near the right edge it may leave the screen first. `SEAFOX_HOMING_ACCEL` sets the acceleration (lower means wider turns). After about 400 ticks without a hit it flies straight off screen. It only chases enemy subs, not mines, aimed shots, surface ships or refueling ships, though anything it runs into still explodes. Only one can be on screen at a time; each costs 2 rounds of ammunition, so it can't be fired with 1 left.

**Game speed**: the original game has no timer. Each pass of the main loop is one tick and the next starts immediately, so the game runs fast with few objects and slow with many, exactly as on real hardware. The modded version does two things. A metronome spaces ticks at least 1/17.5 s apart, so the game no longer speeds up when the screen is empty. The TransWarp card raises the CPU from 1.02 MHz to about 3.58 MHz, so busy scenes still finish in time: on level 5, 99% of ticks take under 36 ms (without the card, 35% of ticks are slower than 30 per second and the slowest takes 123 ms). The card drops back to 1 MHz while loading the tape and playing sound, because the tape loader counts CPU cycles and the speaker pitch comes from delay loops; at full speed the tape would misread and the sound would be too high. Without `a2twarp.zip` only the metronome is active and later levels still slow down.

**Number of upward shots**: each upward shot drags a trail that must be redrawn, which is expensive. Without the card, 1/2/3 shots on screen give about 45/22/12 ticks per second, so the default is 1 without the card. With the card, 3 shots still run at about 28 ticks per second or more, so the default is 3. Forward shots are cheap and unaffected.

## Second game: Lode Runner (警察抓小偷)

The 1988 cassette release of *Lode Runner* by 成都三开元电脑经营部 (the title screen reads "警察抓小偷 (LODE RUNNER 九)"), unmodified.

```sh
./play_loderunner.sh
```

Throttling is again off while loading. The Chinese title screen appears within a few seconds; press any key at "HIT ANY KEY TO BEGIN". A demo follows; press a key again to enter level 1. Each level (and each life) also waits for a key press.

| Key | Action |
|---|---|
| Arrow keys | Move, climb ladders and ropes; move while held, stop when released |
| Z / X (or U / O) | Dig left / right |
| Esc | Pause, Esc again to resume |
| Ctrl-A | Give up this life (when trapped) |
| Ctrl-R | End the game |
| Ctrl-S | Sound on/off |
| Ctrl-H / Ctrl-U | Slower / faster game |

The original direction keys are I/J/K/L: one press keeps moving and Space stops; they still work. The host arrow keys normally arrive on the emulated keyboard as Ctrl-H/U/K/J, which change game speed and switch to joystick mode, so `tools/loderunner_controls.lua` turns them into held I/J/K/L.

**The original recordings can't be used directly**, for two reasons:

- The waveform is asymmetric, and the CEC-I ROM tape routine can't lock onto the sync bit in MAME, so they don't load as is.
- Both sides are damaged and neither is complete on its own. The tape holds three records: on side A the third record (the game itself) has 12 bad blocks; on side B the second record (the title screen) has a one-bit error that happens to pass the block checksum, so the loader can't detect it.

On first run `tools/loderunner_tape.py` decodes both sides, picks the intact copy of each record by its known SHA1 (record 1 is identical on both sides, record 2 comes from side A, record 3 from side B) and writes a clean standard tape, `tapes/loderunner/clean.wav`, which is what actually gets played. Format and loading details are in section 6 of [docs/TECHNICAL.md](docs/TECHNICAL.md) (Chinese).

## Files

```
play_seafox.sh             Launcher (--original for the original, 1-5 for the starting level)
setup.sh                   Check MAME, download tapes and manual, verify ROMs
tools/play_seafox.lua      Autoload: type the load command, play the tape, restore normal speed
tools/seafox_controls.lua  Modded: arrow-key control layer
tools/seafox_patches.lua   Modded: firing limits, fuel use, infinite lives, sub speed
tools/seafox_torpedoes.lua Modded: left firing, homing torpedoes
tools/seafox_speed.lua     Modded: metronome for a fixed tick rate
tools/seafox_accel.lua     Modded: TransWarp card on/off (slows down for tape and sound)
tools/research/            Tape decoding and code analysis scripts (not needed to play)
docs/TECHNICAL.md          Tape format, loading process, game internals (Chinese)
tapes/seafox/              Sea Fox tapes (recordings downloaded by setup.sh) and archive.org transfer notes
play_loderunner.sh         Lode Runner launcher
tools/play_loderunner.lua  Lode Runner autoload
tools/loderunner_controls.lua Lode Runner arrow-key control layer
tools/loderunner_tape.py   Lode Runner tape decoder and re-encoder
tapes/loderunner/          Lode Runner tapes (recordings downloaded by setup.sh, clean.wav generated)
```

## Notes

- Tested on macOS with MAME 0.289. The scripts use MAME's Lua API and may need changes for very different versions.
- The tape recordings and manual come from transfers on archive.org; copyright belongs to the original authors.
- Tape format and game internals are documented in [docs/TECHNICAL.md](docs/TECHNICAL.md) (Chinese).
