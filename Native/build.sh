#!/usr/bin/env bash
set -euo pipefail
mkdir -p build
clang++ --target=x86_64-pc-windows-msvc -O2 -ffreestanding -fno-exceptions -fno-rtti -fno-stack-protector -fno-builtin -c src/bettergamepad.cpp -o build/bettergamepad.obj
lld-link /dll /noentry /nodefaultlib /timestamp:0 /out:build/BetterGamepad.raw.dll \
  /export:bettergamepad_apply \
  /export:bettergamepad_riding_skill1_aim_on \
  /export:bettergamepad_riding_skill1_aim_off \
  /export:bettergamepad_suppress_reloadcoop_on \
  /export:bettergamepad_suppress_reloadcoop_off \
  /export:bettergamepad_suppress_ridingskill3_on \
  /export:bettergamepad_multi_ridingskill3_off \
  /export:bettergamepad_riding_skill3 \
  /export:bettergamepad_tap_context \
  /export:bettergamepad_partner_skill \
  /export:bettergamepad_partner_skill_release \
  /export:bettergamepad_partner_skill_arm_clear \
  /export:bettergamepad_partner_skill_if_physical_hold \
  /export:bettergamepad_aim_multi_press \
  /export:bettergamepad_aim_multi_release \
  /export:bettergamepad_disable_multi_action_melee \
  /export:bettergamepad_finish_melee \
  /export:bettergamepad_controller_reset \
  /export:bettergamepad_controller_hex_0 \
  /export:bettergamepad_controller_hex_1 \
  /export:bettergamepad_controller_hex_2 \
  /export:bettergamepad_controller_hex_3 \
  /export:bettergamepad_controller_hex_4 \
  /export:bettergamepad_controller_hex_5 \
  /export:bettergamepad_controller_hex_6 \
  /export:bettergamepad_controller_hex_7 \
  /export:bettergamepad_controller_hex_8 \
  /export:bettergamepad_controller_hex_9 \
  /export:bettergamepad_controller_hex_a \
  /export:bettergamepad_controller_hex_b \
  /export:bettergamepad_controller_hex_c \
  /export:bettergamepad_controller_hex_d \
  /export:bettergamepad_controller_hex_e \
  /export:bettergamepad_controller_hex_f \
  build/bettergamepad.obj
python3 src/embed_resources.py build/BetterGamepad.raw.dll build/BetterGamepad.dll
rm -f build/BetterGamepad.raw.dll
python3 verify_build.py build/BetterGamepad.dll
