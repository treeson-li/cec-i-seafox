import sys
I = sys.argv[1]; side = sys.argv[2]; out = sys.argv[3]
r3 = open('%s/face%s_r3_0800-1FFF.bin' % (I, side), 'rb').read()
r4 = open('%s/face%s_r4_4000-AA01.bin' % (I, side), 'rb').read()
m = bytearray(0x10000); own = ['--'] * 0x10000
def put(addr, data, tag):
    for i, b in enumerate(data): m[addr + i] = b; own[addr + i] = tag
put(0x0800, r3, 'R3')                      # $0800-$1FFF from loader stage 3
put(0x2000, r4, 'R4')                      # MOVE $4000-$AA01 -> $2000 ($032B code)
put(0x0000, m[0x2000:0x2900], 'R4>0000')   # $2900 relocator: $2000-$28FF -> $0000
put(0x8A00, m[0x2A00:0x6000], 'R4>8A00')   # $2900 relocator: $2A00-$5FFF -> $8A00-$BFFF
open(out, 'wb').write(m[:0xC000])
runs = []; cur = None
for a in range(0xC000):
    if cur and own[a] == cur[0]: cur[2] = a
    else: cur = [own[a], a, a]; runs.append(cur)
for t, a, b in runs: print('  $%04X-$%04X  %s' % (a, b, t))
