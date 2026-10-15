import sys
side = sys.argv[1]; D = sys.argv[2] if len(sys.argv) > 2 else '.'  # 项目根目录
# (record, start, end inclusive) taken from the loader setup code in R1 ($0300, $034E) and R2
plan = [(2, 0x0800, 0x0950), (3, 0x0800, 0x1FFF), (4, 0x4000, 0xAA01)]
for r, a, e in plan:
    s = open('%s/decoded/face%s_r%d.bin' % (D, side, r), 'rb').read()
    n = e - a + 1; out = bytearray(); p = 0; ck = 0xFF; blocks = []; cnt = 0
    while len(out) < n:
        b = s[p]; p += 1; out.append(b); ck ^= b; cnt = (cnt + 1) & 0xFF
        if cnt == 0:
            blocks.append((len(out) // 256, s[p], ck, s[p] == ck)); p += 1; ck = 0xFF
    bad = [x for x in blocks if not x[3]]
    print('R%d -> $%04X-$%04X: %d bytes, consumed %d of %d stream bytes (%d left: %s); %d block checksums, %d bad%s' % (
        r, a, e, n, p, len(s), len(s) - p, s[p:p+6].hex(), len(blocks), len(bad), '' if not bad else ' ' + str(bad[:3])))
    open('%s/images/face%s_r%d_%04X-%04X.bin' % (D, side, r, a, e), 'wb').write(out)
