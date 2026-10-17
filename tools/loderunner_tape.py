# 《警察抓小偷》(Lode Runner) 磁带：从 archive.org 的两面录音解码，合成一盘干净的标准磁带
#
# 原录音波形上下不对称，同步位附近半周期长短不一，CEC-I ROM 的读带例程在 MAME 里对不准同步位
# （读错位或整段漏掉），所以先在这里解码，再按标准 Apple II 磁带格式重新合成。
# 三条记录（见 docs/TECHNICAL.md）：
#   R1  Monitor 格式，$0030-$003D + $023E-$03FF（写到 $3C/$3D 时把 A1 改成 $023E）
#   R2  $0300 例程的分块格式（每 256 字节跟一个 XOR 校验，初值 $FF），$0800-$0970
#   R3  同上，$4000-$B949
# 每条记录在两面、各种同步对齐里找 SHA1 对得上的那份；A 面 R3 有坏块，B 面 R2 偶然通过校验但错了位。
#
# 用法: python3 tools/loderunner_tape.py tapes/loderunner/"Face A.wav" tapes/loderunner/"Face B.wav" 输出.wav
import array, hashlib, struct, sys, wave

EXPECT = {  # 记录数据（不含校验字节）的 SHA1
    1: "7b6def3f0ee2487f10ab6a78f26db445272dd4fb",
    2: "bb4d4aee22254413f33945a2254a437af61949db",
    3: "38139fdad0652b1846c597f1720e7772f928a0b5",
}
LENGTH = {1: 464, 2: 0x0970 - 0x0800 + 1, 3: 0xB949 - 0x4000 + 1}


def records(path):
    """按整周期（上升过零到上升过零，带滞回）切出各条记录的位流"""
    w = wave.open(path)
    n, sr = w.getnframes(), w.getframerate()
    d = struct.unpack("<%dh" % n, w.readframes(n))
    cyc, state, last = [], -1, 0
    for i, x in enumerate(d):
        if state < 0 and x > 2000:
            cyc.append((i - last) * 1e6 / sr)
            last, state = i, 1
        elif state > 0 and x < -2000:
            state = -1
    out, j = [], 0
    while j < len(cyc):
        k = j
        while k < len(cyc) and 1230 < cyc[k] < 1700:  # leader 约 1300µs
            k += 1
        if k - j < 200:
            j = max(k, j + 1)
            continue
        p, bits = k, []
        while p < len(cyc) and cyc[p] < 1230:  # 0 约 500µs，1 约 1000µs
            bits.append(0 if cyc[p] < 750 else 1)
            p += 1
        if len(bits) > 1000:  # leader 中间的毛刺会切出空记录
            out.append(bits)
        j = p
    return out


def to_bytes(bits):
    out = bytearray()
    for i in range(0, len(bits) - 7, 8):
        b = 0
        for bit in bits[i:i + 8]:
            b = b << 1 | bit
        out.append(b)
    return bytes(out)


def unblock(raw, length):
    data, pos = bytearray(), 0
    while len(data) < length:
        blk = raw[pos:pos + min(256, length - len(data))]
        if not blk:
            return b""
        data += blk
        pos += len(blk) + (1 if len(blk) == 256 else 0)
    return bytes(data[:length])


def find(faces):
    found = {}
    for recs in faces:
        for num, bits in enumerate(recs[:3], 1):
            if num in found:
                continue
            for shift in range(8):
                raw = to_bytes(bits[shift:])
                data = raw[:LENGTH[1]] if num == 1 else unblock(raw, LENGTH[num])
                if hashlib.sha1(data).hexdigest() == EXPECT[num]:
                    found[num] = data
                    break
    return found


def synth(recs, path):
    """标准 Apple II 格式：leader 770Hz，同步 200+250µs，0 = 250+250µs，1 = 500+500µs"""
    sr, amp = 44100, 20000
    buf, lvl, acc = array.array("h"), [amp], [0.0]

    def half(us):
        acc[0] += us * sr / 1e6
        k = int(acc[0])
        acc[0] -= k
        buf.extend([lvl[0]] * k)
        lvl[0] = -lvl[0]

    def leader(sec):
        for _ in range(int(sec * 1e6 / 1300)):
            half(650); half(650)

    def byte(b):
        for i in range(7, -1, -1):
            us = 500 if b >> i & 1 else 250
            half(us); half(us)

    def xor(data):
        x = 0xFF
        for b in data:
            x ^= b
        return x

    def record(sec, data, blocked):
        leader(sec)
        half(200); half(250)
        for i in range(0, len(data), 256 if blocked else len(data)):
            blk = data[i:i + 256] if blocked else data
            for b in blk:
                byte(b)
            if not blocked or len(blk) == 256:
                byte(xor(blk))
        for _ in range(4):
            half(500)

    buf.extend([0] * sr)
    # R1 前的 leader 要比 ROM 读带例程开头的固定延时（约 3.5 秒）长，见 play_loderunner.lua 的 ENTER_AT
    record(4.5, recs[1], False)
    record(3.3, recs[2], True)
    record(3.5, recs[3], True)
    buf.extend([0] * sr)
    o = wave.open(path, "wb")
    o.setnchannels(1); o.setsampwidth(2); o.setframerate(sr)
    o.writeframes(buf.tobytes())
    o.close()


if __name__ == "__main__":
    *inputs, output = sys.argv[1:]
    recs = find(records(p) for p in inputs)
    missing = [n for n in (1, 2, 3) if n not in recs]
    if missing:
        sys.exit("解码失败，找不到记录 %s" % missing)
    synth(recs, output)
    print("已生成", output)
