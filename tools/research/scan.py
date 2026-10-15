import sys, wave, struct
w = wave.open(sys.argv[1]); n = w.getnframes(); sr = w.getframerate()
d = struct.unpack('<%dh' % n, w.readframes(n))
for th in (800, 1500, 3000):
    state = 1 if d[0] > 0 else -1; last = 0; hc = []
    for i, x in enumerate(d):
        if (state < 0 and x > th) or (state > 0 and x < -th):
            hc.append(((i - last) * 1e6 / sr, last / sr)); last = i; state = -state
    N = len(hc); runs = []; j = 0
    while j < N:
        k = j
        while k < N and 520 < hc[k][0] < 820: k += 1
        if k - j >= 30: runs.append((j, k))
        j = max(k, j + 1)
    print('threshold', th, 'half-cycles', N, 'leader-like runs (>=30):', len(runs))
    for j, k in runs:
        nxt = ' '.join('%.0f' % hc[m][0] for m in range(k, min(k + 4, N)))
        print('  %.2fs-%.2fs  %d half-cycles  next: %s' % (hc[j][1], hc[k-1][1], k - j, nxt))
    # data-like activity segments: consecutive half-cycles 150..600us
    segs = []; j = 0
    while j < N:
        k = j
        while k < N and 150 < hc[k][0] < 600: k += 1
        if k - j >= 160: segs.append((hc[j][1], hc[k-1][1], k - j))
        j = max(k, j + 1)
    print('  data-like segments (>=160 half-cycles = ~10 bytes):')
    for a, b, c in segs: print('    %.2fs-%.2fs %d' % (a, b, c))
