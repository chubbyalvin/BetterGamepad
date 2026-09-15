@echo off
setlocal
if not exist build mkdir build
clang++ --target=x86_64-pc-windows-msvc -O2 -ffreestanding -fno-exceptions -fno-rtti -fno-stack-protector -fno-builtin -c src\bettergamepad.cpp -o build\bettergamepad.obj
if errorlevel 1 exit /b 1
lld-link /dll /noentry /nodefaultlib /timestamp:0 /out:build\BetterGamepad.raw.dll ^
  /export:bettergamepad_apply ^
  /export:bettergamepad_suppress_reloadcoop_on ^
  /export:bettergamepad_suppress_reloadcoop_off ^
  /export:bettergamepad_suppress_ridingskill3_on ^
  /export:bettergamepad_multi_ridingskill3_off ^
  /export:bettergamepad_riding_skill3 ^
  /export:bettergamepad_tap_context ^
  /export:bettergamepad_tap_partner_priority ^
  /export:bettergamepad_partner_skill ^
  /export:bettergamepad_aim_multi_press ^
  /export:bettergamepad_aim_multi_release ^
  /export:bettergamepad_finish_melee ^
  build\bettergamepad.obj
if errorlevel 1 exit /b 1
python src\embed_resources.py build\BetterGamepad.raw.dll build\BetterGamepad.dll
if errorlevel 1 exit /b 1
del /q build\BetterGamepad.raw.dll
python verify_build.py build\BetterGamepad.dll
if errorlevel 1 exit /b 1
echo Built build\BetterGamepad.dll
