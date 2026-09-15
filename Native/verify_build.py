#!/usr/bin/env python3
from pathlib import Path
import hashlib, struct, sys

EXPECTED_SHA256 = "5f3732e9c8ab46a78b5d833109f8e4a0f6e40dc6e918a0be80dd03aa7a24539a"
EXPECTED_EXPORTS = {
    "bettergamepad_apply",
    "bettergamepad_suppress_reloadcoop_on",
    "bettergamepad_suppress_reloadcoop_off",
    "bettergamepad_suppress_ridingskill3_on",
    "bettergamepad_multi_ridingskill3_off",
    "bettergamepad_riding_skill3",
    "bettergamepad_tap_context",
    "bettergamepad_tap_partner_priority",
    "bettergamepad_partner_skill",
    "bettergamepad_aim_multi_press",
    "bettergamepad_aim_multi_release",
    "bettergamepad_finish_melee",
}
MARKER = b"BetterGamepad Native Helper | v1.0 | by ChubbyAlvin\0"

def rva_to_off(data, sections, rva):
    for va, vs, rawsz, rawptr in sections:
        if va <= rva < va + max(vs, rawsz):
            return rawptr + (rva - va)
    raise ValueError(f"unmapped RVA 0x{rva:X}")

def parse_exports(data):
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    coff = pe + 4
    nsec = struct.unpack_from('<H', data, coff + 2)[0]
    optsz = struct.unpack_from('<H', data, coff + 16)[0]
    opt = coff + 20
    sections=[]
    st=opt+optsz
    for i in range(nsec):
        o=st+i*40
        vs,va,rawsz,rawptr=struct.unpack_from('<IIII',data,o+8)
        sections.append((va,vs,rawsz,rawptr))
    exp_rva = struct.unpack_from('<I',data,opt+112)[0]
    eo=rva_to_off(data,sections,exp_rva)
    nnames=struct.unpack_from('<I',data,eo+24)[0]
    names_rva=struct.unpack_from('<I',data,eo+32)[0]
    names_off=rva_to_off(data,sections,names_rva)
    names=set()
    for i in range(nnames):
        nrva=struct.unpack_from('<I',data,names_off+4*i)[0]
        no=rva_to_off(data,sections,nrva)
        end=data.index(b'\0',no)
        names.add(data[no:end].decode('ascii'))
    # import directory must be absent
    imp_rva, imp_size = struct.unpack_from('<II',data,opt+112+8)
    return names, imp_rva, imp_size

def main():
    path=Path(sys.argv[1] if len(sys.argv)>1 else 'build/BetterGamepad.dll')
    data=path.read_bytes()
    digest=hashlib.sha256(data).hexdigest()
    print('SHA-256:', digest)
    if digest != EXPECTED_SHA256:
        raise SystemExit('unexpected build hash')
    exports, imp_rva, imp_size = parse_exports(data)
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    opt = pe + 4 + 20
    res_rva, res_size = struct.unpack_from('<II', data, opt + 112 + 2*8)
    if exports != EXPECTED_EXPORTS:
        print('missing:', sorted(EXPECTED_EXPORTS-exports))
        print('extra:', sorted(exports-EXPECTED_EXPORTS))
        raise SystemExit('export mismatch')
    if imp_rva or imp_size:
        raise SystemExit('unexpected import table')
    if MARKER not in data:
        raise SystemExit('branding marker missing')
    if not res_rva or not res_size:
        raise SystemExit('VERSIONINFO/resource directory missing')
    for text in ('BetterGamepad Native Helper', 'ChubbyAlvin', 'FileVersion', 'ProductVersion'):
        if (text + '\0').encode('utf-16le') not in data:
            raise SystemExit(f'VERSIONINFO text missing: {text}')
    if b'_v1\0' in data or b'aim_square' in data or b'suppress_ridingskill3_off' in data:
        raise SystemExit('legacy export text present')
    print('Exports: PASS')
    print('No imports: PASS')
    print('Branding marker: PASS')
    print('VERSIONINFO/resources: PASS')
    print('PASS')

if __name__=='__main__': main()
