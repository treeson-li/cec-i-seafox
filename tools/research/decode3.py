import sys, wave, struct
src, outprefix = sys.argv[1], sys.argv[2]
w = wave.open(src); n = w.getnframes(); sr = w.getframerate()
d = struct.unpack('<%dh' % n, w.readframes(n))
th = 1500; state = 1 if d[0] > 0 else -1; last = 0; hc = []
for i, x in enumerate(d):
    if (state < 0 and x > th) or (state > 0 and x < -th):
        hc.append(((i - last) * 1e6 / sr, last / sr)); last = i; state = -state
N = len(hc); j = 0; rec = 0; minc = []
while j < N:
    k = j
    while k < N and 520 < hc[k][0] < 820: k += 1
    if k - j < 300: j = max(k, j + 1); continue
    p = k + 2; data = []; cur = 0; nb = 0; cyc = []
    while p + 1 < N:
        c = hc[p][0] + hc[p+1][0]
        if c >= 1180: break
        bit = 0 if c < 750 else 1; cyc.append((bit, c))
        cur = (cur << 1) | bit; nb += 1; p += 2
        if nb == 8: data.append(cur); cur = 0; nb = 0
    if len(data) >= 2:
        rec += 1
        body, ck = data[:-1], data[-1]
        xf = 0xFF; x0 = 0
        for b in body: xf ^= b; x0 ^= b
        z = [c for b, c in cyc if b == 0]; o = [c for b, c in cyc if b == 1]
        # margin: worst cycles closest to the 750us decision threshold
        print('R%d sync@%.2fs  data=%d bytes  ck=$%02X  XOR(init FF)=$%02X %s  XOR(init 00)=$%02X %s  leftover=%d  0-cycles %d..%dus  1-cycles %d..%dus' % (rec, hc[k][1], len(body), ck, xf, 'OK' if xf == ck else '--', x0, 'OK' if x0 == ck else '--', nb, min(z), max(z), min(o), max(o)))
        open('%s_r%d.bin' % (outprefix, rec), 'wb').write(bytes(body))
    j = k + 1
