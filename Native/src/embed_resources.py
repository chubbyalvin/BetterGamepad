from pathlib import Path
import struct
import sys

MARKER = "BetterGamepad Native Helper | v1.0 | by ChubbyAlvin"


def align(n, a=4):
    return (n + a - 1) & ~(a - 1)


def wstr(s):
    return (s + "\0").encode("utf-16le")


def block(key, value=b"", value_length=0, value_type=1, children=()):
    """Build an aligned VERSIONINFO block."""
    out = bytearray(b"\0" * 6)
    out += wstr(key)
    out += b"\0" * (align(len(out), 4) - len(out))
    out += value
    if children:
        out += b"\0" * (align(len(out), 4) - len(out))
        for child in children:
            out += child
            out += b"\0" * (align(len(out), 4) - len(out))
    struct.pack_into("<HHH", out, 0, len(out), value_length, value_type)
    return bytes(out)


def string_block(key, value):
    raw = wstr(value)
    return block(key, raw, len(value) + 1, 1)


def build_version_info():
    fixed = struct.pack(
        "<13I",
        0xFEEF04BD,  # VS_FFI_SIGNATURE
        0x00010000,  # VS_FFI_STRUCVERSION
        0x00010000,  # FileVersion MS: 1.0
        0x00000000,  # FileVersion LS
        0x00010000,  # ProductVersion MS: 1.0
        0x00000000,  # ProductVersion LS
        0x0000003F,  # VS_FFI_FILEFLAGSMASK
        0x00000000,  # flags
        0x00040004,  # VOS_NT_WINDOWS32
        0x00000002,  # VFT_DLL
        0x00000000,
        0x00000000,
        0x00000000,
    )

    strings = [
        ("CompanyName", "ChubbyAlvin"),
        ("FileDescription", MARKER),
        ("FileVersion", "1.0.0.0"),
        ("InternalName", "BetterGamepad.dll"),
        ("LegalCopyright", "by ChubbyAlvin"),
        ("OriginalFilename", "BetterGamepad.dll"),
        ("ProductName", "BetterGamepad Native Helper"),
        ("ProductVersion", "1.0"),
        ("Comments", MARKER),
    ]
    table = block("040904B0", children=[string_block(k, v) for k, v in strings])
    string_file_info = block("StringFileInfo", children=[table])
    translation = block("Translation", struct.pack("<HH", 0x0409, 0x04B0), 4, 0)
    var_file_info = block("VarFileInfo", children=[translation])
    return block("VS_VERSION_INFO", fixed, len(fixed), 0, [string_file_info, var_file_info])


def resource_directory(id_count):
    return struct.pack("<IIHHHH", 0, 0, 0, 0, 0, id_count)


def resource_entry(resource_id, target_offset, is_directory):
    target = target_offset | (0x80000000 if is_directory else 0)
    return struct.pack("<II", resource_id, target)


def build_resources(resource_rva):
    """Build RT_RCDATA #101 and RT_VERSION #1, language en-US."""
    version = build_version_info()
    marker = (MARKER + "\0").encode("ascii")

    # Directory layout offsets relative to start of resource directory.
    root_off = 0
    type_rcdata_off = 32
    type_version_off = 56
    id_rcdata_off = 80
    id_version_off = 104
    rcdata_entry_off = 128
    version_entry_off = 144
    data_off = 160

    marker_off = data_off
    version_off = align(marker_off + len(marker), 4)
    total = align(version_off + len(version), 4)
    out = bytearray(total)

    # Root: RT_RCDATA (10), RT_VERSION (16)
    out[root_off:root_off+16] = resource_directory(2)
    out[16:24] = resource_entry(10, type_rcdata_off, True)
    out[24:32] = resource_entry(16, type_version_off, True)

    # Type -> resource ID
    out[type_rcdata_off:type_rcdata_off+16] = resource_directory(1)
    out[type_rcdata_off+16:type_rcdata_off+24] = resource_entry(101, id_rcdata_off, True)
    out[type_version_off:type_version_off+16] = resource_directory(1)
    out[type_version_off+16:type_version_off+24] = resource_entry(1, id_version_off, True)

    # Resource ID -> language 0x0409 -> data entry
    out[id_rcdata_off:id_rcdata_off+16] = resource_directory(1)
    out[id_rcdata_off+16:id_rcdata_off+24] = resource_entry(0x0409, rcdata_entry_off, False)
    out[id_version_off:id_version_off+16] = resource_directory(1)
    out[id_version_off+16:id_version_off+24] = resource_entry(0x0409, version_entry_off, False)

    # IMAGE_RESOURCE_DATA_ENTRY
    struct.pack_into("<IIII", out, rcdata_entry_off,
                     resource_rva + marker_off, len(marker), 0, 0)
    struct.pack_into("<IIII", out, version_entry_off,
                     resource_rva + version_off, len(version), 1200, 0)

    out[marker_off:marker_off+len(marker)] = marker
    out[version_off:version_off+len(version)] = version
    return bytes(out)


def parse_pe(data):
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe+4] != b"PE\0\0":
        raise SystemExit("not a PE file")
    coff = pe + 4
    machine, nsec, _, _, _, opt_size, _ = struct.unpack_from("<HHIIIHH", data, coff)
    if machine != 0x8664:
        raise SystemExit("expected x86-64 PE")
    opt = coff + 20
    if struct.unpack_from("<H", data, opt)[0] != 0x20B:
        raise SystemExit("expected PE32+")
    sec_table = opt + opt_size
    sections = []
    for i in range(nsec):
        o = sec_table + i * 40
        name = data[o:o+8].rstrip(b"\0").decode("ascii", "replace")
        vs, va, rawsz, rawptr = struct.unpack_from("<IIII", data, o + 8)
        sections.append((name, o, vs, va, rawsz, rawptr))
    return opt, sections


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: embed_resources.py INPUT.dll OUTPUT.dll")
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    data = bytearray(src.read_bytes())
    opt, sections = parse_pe(data)

    # Refuse to stack another resource table onto an already resource-bearing DLL.
    resource_dir_off = opt + 112 + 2 * 8
    old_resource_rva, old_resource_size = struct.unpack_from("<II", data, resource_dir_off)
    if old_resource_rva or old_resource_size:
        raise SystemExit("input already has a PE resource directory")

    rdata = next((s for s in sections if s[0] == ".rdata"), None)
    if not rdata:
        raise SystemExit(".rdata section not found")
    _, sh, old_vs, va, old_rawsz, rawptr = rdata
    file_alignment = struct.unpack_from("<I", data, opt + 36)[0]
    section_alignment = struct.unpack_from("<I", data, opt + 32)[0]

    expected_end = rawptr + old_rawsz
    if len(data) != expected_end:
        raise SystemExit(f"expected .rdata to end at EOF ({expected_end:#x}), file is {len(data):#x}")

    resource_rva = va + old_rawsz
    blob = build_resources(resource_rva)
    virtual_extent = old_rawsz + len(blob)
    if virtual_extent > section_alignment:
        raise SystemExit("resource data would overlap the next virtual section")
    new_rawsz = align(virtual_extent, file_alignment)
    new_vs = max(old_vs, virtual_extent)

    data += blob
    data += b"\0" * (rawptr + new_rawsz - len(data))

    # Expand .rdata in-place; no existing RVA or code byte moves.
    struct.pack_into("<I", data, sh + 8, new_vs)       # VirtualSize
    struct.pack_into("<I", data, sh + 16, new_rawsz)  # SizeOfRawData

    # Resource data-directory entry.
    struct.pack_into("<II", data, resource_dir_off, resource_rva, len(blob))

    # SizeOfInitializedData grows by the new raw bytes in .rdata.
    old_init = struct.unpack_from("<I", data, opt + 8)[0]
    struct.pack_into("<I", data, opt + 8, old_init + (new_rawsz - old_rawsz))

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(data)
    print(f"embedded marker: {MARKER}")
    print(f"resource RVA: 0x{resource_rva:X}, resource size: {len(blob)} bytes")
    print(f".rdata raw size: 0x{old_rawsz:X} -> 0x{new_rawsz:X}")

if __name__ == "__main__":
    main()
