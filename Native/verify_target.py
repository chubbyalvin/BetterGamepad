import hashlib, struct, sys
from pathlib import Path

EXPECTED_SHA256 = "44b6295e70aa37b83d1c42ce1dcf865a7ffadcd300298b0e49a02bad8eb83443"
IMAGE_BASE = 0x140000000
CHECKS = {
    0x14315D510: bytes.fromhex("40 57 48 83 EC"),
    0x14315D227: bytes.fromhex("75 1C"),
    0x14315F246: bytes.fromhex("74 2B"),
    0x14316C58E: bytes.fromhex("48 8D 05 5B FA FE FF"),
    0x14316C59F: bytes.fromhex("48 8D 05 EA 2B FF FF"),
    0x14316C5AE: bytes.fromhex("48 8D 05 7B F9 FE FF"),
    0x14316C5BD: bytes.fromhex("48 8D 05 BC 02 FF FF"),
}
CODE_CAVE = 0x14082C100


def sections(data):
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    n = struct.unpack_from("<H", data, pe + 6)[0]
    opt = struct.unpack_from("<H", data, pe + 20)[0]
    s = pe + 24 + opt
    out=[]
    for i in range(n):
        o=s+40*i
        vsize, vrva, rsize, roff = struct.unpack_from("<IIII", data, o+8)
        out.append((vrva, max(vsize, rsize), roff))
    return out


def va_to_off(data, va):
    rva=va-IMAGE_BASE
    for srva, ssize, soff in sections(data):
        if srva <= rva < srva+ssize:
            return soff+(rva-srva)
    raise ValueError(hex(va))


def main():
    if len(sys.argv)!=2:
        print("Usage: python verify_target.py Palworld-Win64-Shipping.exe")
        raise SystemExit(2)
    data=Path(sys.argv[1]).read_bytes()
    digest=hashlib.sha256(data).hexdigest()
    ok=digest==EXPECTED_SHA256
    print("SHA-256:",digest)
    print("Exact target hash:","YES" if ok else "NO")
    for va, expected in CHECKS.items():
        off=va_to_off(data,va)
        got=data[off:off+len(expected)]
        match=got==expected
        ok &= match
        print(f"0x{va:X}: {'OK' if match else 'MISMATCH'} got={got.hex(' ')}")
    off=va_to_off(data,CODE_CAVE)
    cave_ok=data[off:off+128] == b"\xCC"*128
    ok &= cave_ok
    print("128-byte code cave:","OK" if cave_ok else "MISMATCH")
    raise SystemExit(0 if ok else 1)


if __name__ == "__main__":
    main()
