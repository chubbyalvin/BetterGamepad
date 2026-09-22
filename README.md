# BetterGamepad

**BetterGamepad** improves Palworld's controller controls with a configurable context-sensitive multi-action button, improved riding-skill handling, and a fix for the flying-mount Skill 3 conflict.

## Features

- **Configurable context-sensitive MultiAction button** — defaults to Square on PlayStation / X on Xbox and handles the appropriate action depending on context, including ranged reload and melee use.
- **Configurable MultiAction features** — Reload, melee, and Coop / Partner Skill handling can be enabled or disabled independently in `config.lua`.
- **Hold MultiAction for Partner Skill** — default hold time is 350 ms.
- **Partner Skill Arming** — hold the Partner Skill button before summoning a Pal to arm its Partner Skill. When the Pal appears, the Partner Skill activates immediately.
- **Riding Skill 1 while aiming** — when Riding Skill 1 is bound to a different button from WeaponUse / Fire, it remains usable while aiming and its real skill name stays visible. If both actions share the same button, BetterGamepad leaves Palworld's vanilla contextual behavior unchanged.
- **Riding Skill 3 routing** — BetterGamepad reads Palworld's hidden `RidingSkill3_GamePad` binding and uses the button assigned to it.
- **Flying-mount conflict fix** — Roll / Crouch / Descend no longer accidentally triggers Riding Skill 3.
- Supports both **Main** and **Secondary** controller bindings stored in `UserOption.sav`.

---

# IMPORTANT: `UserOption.sav` controls how BetterGamepad behaves

**Please do not skip this section.**

Palworld does **not** let you reassign `RidingSkill3_GamePad` from the normal in-game controller settings. BetterGamepad reads that hidden binding directly from your `UserOption.sav`.

> **Your `UserOption.sav` determines which button BetterGamepad uses for Riding Skill 3 and therefore directly affects how the mod behaves.**

Ready-made presets are included in:

```text
BetterGamepad\Scripts\UserOption Presets\
```

### Included standard presets

| Preset | Riding Skill 3 button |
|---|---|
| `UserOption_BetterGamepad_1_Skill3_on_X.sav` | Square / X — Face Button Left |
| `UserOption_BetterGamepad_2_Skill3_on_DPadUp.sav` | D-Pad Up |
| `UserOption_BetterGamepad_3_Skill3_on_RT.sav` | R2 / RT |
| `UserOption_BetterGamepad_4_Skill3_on_LB.sav` | L1 / LB |

The **Square / X** preset keeps Riding Skill 3 integrated with BetterGamepad's multi-action button.

### PalWheel presets

If you also use **PalWheel**, use one of the presets inside:

```text
BetterGamepad\Scripts\UserOption Presets\UserOption Presets for PalWheel\
```

| Preset | Riding skill layout |
|---|---|
| `UserOption_BetterGamepad_0_All_Skills_on_DPad_PalWheel.sav` | Skill 1 = D-Pad Left, Skill 2 = D-Pad Right, Skill 3 = D-Pad Up |
| `UserOption_BetterGamepad_1_Skill3_on_X_PalWheel.sav` | Skill 3 = Square / X — Face Button Left |
| `UserOption_BetterGamepad_2_Skill3_on_DPadUp_PalWheel.sav` | Skill 3 = D-Pad Up |
| `UserOption_BetterGamepad_3_Skill3_on_RT_PalWheel.sav` | Skill 3 = R2 / RT |


**Do not use a PalWheel preset unless you are using PalWheel.**

## Installing a `UserOption.sav` preset

1. **Exit Palworld completely.**
2. Open `BetterGamepad\Scripts\UserOption Presets\`.
3. Choose the preset with the Riding Skill 3 button you want. If you use PalWheel, choose the matching preset from the PalWheel subfolder instead.
4. Open:

   ```text
   %LOCALAPPDATA%\Pal\Saved\SaveGames\
   ```

5. Locate your current `UserOption.sav` in that folder.
6. **Back up your existing `UserOption.sav` first.**
7. Copy your chosen preset into that folder.
8. Rename the copied preset to exactly:

   ```text
   UserOption.sav
   ```

9. Replace the existing file, then start Palworld.

> **Warning:** A preset is a complete `UserOption.sav`. Replacing yours can replace controller bindings and other options stored in that file. Keep your backup if you want to restore your previous setup.

## How Riding Skill 3 behaves

When Riding Skill 3 is assigned to **Square / X**, BetterGamepad keeps it integrated with the existing multi-action behavior.

When Riding Skill 3 is assigned to another button, BetterGamepad gives that button **Skill 3-only handling** instead of also giving it Square / X's reload, melee, or Partner Skill behavior.

If Riding Skill 3 shares a button with Roll / Crouch / Descend, BetterGamepad preserves the useful distinction:

- **Short tap** → Riding Skill 3
- **Hold** → Roll / Crouch / Descend

This is why the `UserOption.sav` preset matters: BetterGamepad follows the actual `RidingSkill3_GamePad` assignment stored in the save.

## Installation

BetterGamepad is a UE4SS mod.

Copy the included `BetterGamepad` folder into your UE4SS `Mods` folder so the final layout is:

```text
Mods\
└─ BetterGamepad\
   ├─ enabled.txt
   └─ Scripts\
      ├─ BetterGamepad.dll
      ├─ config.lua
      ├─ main.lua
      └─ UserOption Presets\
```

## Configuration

Default Partner Skill behavior is configured in:

```text
BetterGamepad\Scripts\config.lua
```

Defaults include:

```lua
MultiActionButton = "Gamepad_FaceButton_Left"
EnableReload = true
EnableMeleeOnMultiAction = true
EnableCoop = true
EnableRidingSkill1WhileAiming = true
PartnerSkillTrigger = "Hold"
PartnerSkillHoldMs = 350
PartnerSkillArmTimeout = 0
```

See the comments in `config.lua` for the behavior of each setting.

## Requirements

- Palworld on Windows / Steam
- UE4SS / compatible Palworld UE4SS mod environment

## Repository layout

```text
Scripts/                BetterGamepad Lua files and native helper DLL
UserOption Presets/     Ready-made UserOption.sav presets
Native/                 Native helper source and build scripts
LICENSE                 MIT License
README.md               Project and installation documentation
```

See [`Native/README.md`](Native/README.md) for details about building the native helper from source.

## Native helper

The shipped DLL identifies itself as:

```text
BetterGamepad Native Helper | v1.1 | by ChubbyAlvin
```

The `Native/` folder contains the files and rebuild scripts used to produce the BetterGamepad native helper DLL.

## Author

**BetterGamepad by ChubbyAlvin**
