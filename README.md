# Brotato Cheat Helper

A small local cheat mod for [Brotato](https://store.steampowered.com/app/1942280/Brotato/) on Windows. It adds hotkeys for materials, stats and levels, a material multiplier, and a button to delete items in the shop.

It works through Godot's `override.cfg` autoload, so you don't need a mod loader. It changes only your own local game.

## Features

| Key | What it does | When |
|-----|--------------|------|
| `F5` | +500 materials for every player | During a wave or in the shop |
| `F6` | +5 to all primary stats | During a wave or in the shop |
| `F7` | Gain 1 level (pick the upgrade at the end of the wave) | During a wave |
| `F8` | Turn the material multiplier on / off | Anytime |
| `F9` | Cycle the material multiplier: 1x, 2x, 3x, 5x, 10x, 25x, 50x, 100x (default 5x) | Anytime |

**Shop item delete:** Every item in your inventory gets a red **X** button in its top-right corner. Clicking it removes one copy of the item and reverts its stats. You don't get a refund. Effects left behind by deleted items (turrets, pets, burning, etc.) are also cleaned up, including in runs loaded from a save.

The material multiplier is applied after the game's own bonuses (Metal Detector, material value, etc.). XP is not multiplied.

## Setup

### Requirements
- Windows
- Brotato (Steam version)

### Install
1. Download this repository: **Code → Download ZIP**, then extract it. Or clone it:
   ```bat
   git clone https://github.com/alperyoltay/brotato-cheat-helper.git
   ```
2. Close Brotato if it is running.
3. Double-click **`install.bat`**.

The installer finds Brotato in your Steam libraries automatically. If it can't, it asks for the folder. You can also pass it directly:

```bat
install.bat "D:\SteamLibrary\steamapps\common\Brotato"
```

4. Start Brotato. You should see **"CheatHelper loaded (F5-F9)"** in the top-left corner.

The installer copies the mod into `Brotato\CheatHelper` and writes `Brotato\override.cfg`. After installing, you can delete the downloaded folder.

### Uninstall
Double-click **`uninstall.bat`**. It removes `override.cfg` and the `CheatHelper` folder from the game directory.

### Troubleshooting
- **"belongs to something else"**: Another mod or tool already uses `override.cfg`. The installer won't overwrite it. Back that file up or remove it, then run `install.bat` again.
- **"Could not copy" / "Could not write"**: Right-click `install.bat` → **Run as administrator**.
- **Nothing shows up in game**: Make sure `override.cfg` is in the same folder as `Brotato.exe`, then restart the game.
- **After a game update**: If the game updates and the mod stops working, run `install.bat` again.

## Settings

Change the values at the top of `src/Local-CheatHelper/cheat_autoload.gd`, then run `install.bat` again:

```gdscript
const GOLD_BUTTON_AMOUNT := 500
const STAT_BUTTON_AMOUNT := 5
const MULT_STEPS := [1.0, 2.0, 3.0, 5.0, 10.0, 25.0, 50.0, 100.0]
const DEFAULT_MULT_INDEX := 3 # 5x
```

## How it works

```
install.bat                         Finds the game, copies the mod, writes override.cfg
uninstall.bat                       Removes everything install.bat added
src/Local-CheatHelper/
├── cheat_autoload.gd               Autoload: hotkeys, on-screen messages, shop X buttons
└── extensions/main.gd              Extends the game's main.gd to multiply picked-up materials
```

`override.cfg` registers `cheat_autoload.gd` as an autoload when the game starts. The autoload then replaces `res://main.gd` with `extensions/main.gd` using `take_over_path`, which is the same technique Godot Mod Loader uses.

## Disclaimer

This is a fan-made mod for single-player and local co-op fun. It is not affiliated with or endorsed by Blobfish or Brotato's publishers. Use it at your own risk, and turn it off before you report bugs to the developers.
