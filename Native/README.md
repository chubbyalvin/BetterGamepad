# BetterGamepad Native Helper

**Version 1.1 — by ChubbyAlvin**

This folder contains the source and build scripts used to produce `BetterGamepad.dll`.

The native helper is compiled directly from `src/bettergamepad.cpp`. 


## Files

- `src/bettergamepad.cpp` — native helper source.
- `src/embed_resources.py` — embeds VERSIONINFO into the compiled DLL.
- `build.cmd` — Windows build script.
- `build.sh` — shell build script.
- `verify_build.py` — verifies the finished DLL's hash, exports, import table, and VERSIONINFO resources.
- `verify_target.py` — verifies the supported `Palworld-Win64-Shipping.exe` target build.

## Windows build

Requirements:

- LLVM/Clang with `clang++` and `lld-link` available on `PATH`.
- Python 3 available as `python`.

Run:

```text
build.cmd
```

The finished DLL is written to:

```text
build\BetterGamepad.dll
```

## Shell build

```bash
chmod +x build.sh
./build.sh
```

## Build stages

1. Compile `src/bettergamepad.cpp`.
2. Link a fresh freestanding x64 Windows DLL.
3. Embed the VERSIONINFO and branding resources with `src/embed_resources.py`.
4. Verify the finished DLL with `verify_build.py`.

## Target verification

Before using the helper with a different Palworld executable build, verify the target executable:

```text
python verify_target.py C:\path\to\Palworld-Win64-Shipping.exe
```

Supported target SHA-256:

```text
44b6295e70aa37b83d1c42ce1dcf865a7ffadcd300298b0e49a02bad8eb83443
```

The native helper is freestanding and uses no CRT or import libraries.
