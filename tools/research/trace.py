import sys
exec(open(sys.argv[1]).read().split('def runs_ok')[0].split('import sys')[1])  # reuse opcode length table L
m = open(sys.argv[2], 'rb').read() + bytes(0x4000)
def region(a):
    if a < 0x0900: return '$0000-08FF (R4 reloc)'
    if a < 0x2000: return '$0900-1FFF (R3)'
    if a < 0x8A00: return '$2000-89FF (R4)'
    if a < 0xC000: return '$8A00-BFFF (R4 reloc)'
    return 'ROM/IO'
def trace(entries):
    seen = set(); todo = list(entries); bad = []; rom = set(); jind = []
    while todo:
        a = todo.pop()
        while True:
            if a >= 0xC000: rom.add(a); break
            if a in seen: break
            op = m[a]
            if op not in L or op == 0x00: bad.append((a, op)); break
            seen.add(a); n = L[op]; t = m[a+1] | m[a+2] << 8
            if op in (0x60, 0x40): break
            if op == 0x4C: a = t; continue
            if op == 0x6C: jind.append((a, t)); break
            if op == 0x20: todo.append(t)
            if op & 0x1F == 0x10:   # relative branches
                todo.append((a + 2 + (m[a+1] - 256 if m[a+1] > 127 else m[a+1])) & 0xFFFF)
            a += n
    return seen, bad, rom, jind
for name, ent in [('entry $67D4', [0x67D4]), ('relocator $2900', [0x2900])]:
    seen, bad, rom, jind = trace(ent)
    from collections import Counter
    c = Counter(region(a) for a in seen)
    print('%s: %d instructions reached; illegal/BRK hits: %d %s' % (name, len(seen), len(bad), ['$%04X:%02X' % x for x in bad[:8]]))
    for k, v in sorted(c.items()): print('    %-24s %d instr' % (k, v))
    print('    ROM targets:', ' '.join('$%04X' % x for x in sorted(rom)))
    print('    JMP (ind):', ' '.join('$%04X->($%04X)' % x for x in jind[:8]))
