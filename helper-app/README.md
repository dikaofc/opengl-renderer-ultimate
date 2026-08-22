# ORE Tile — Quick Settings Helper

Quick Settings tile untuk toggle WebUI server dari notification shade.

## Build

### Prerequisites
- Android SDK (command-line tools)
- Java JDK 11+

### Build APK

```bash
cd helper-app
chmod +x build.sh
./build.sh
```

Output: `build/ore-tile.apk`

### Install

```bash
adb install build/ore-tile.apk
```

Or copy the APK to your device and install manually.

## Setup

1. Install the APK
2. Pull down notification shade
3. Tap edit (pencil icon)
4. Find "WebUI Toggle" tile
5. Drag it to your Quick Settings
6. Tap the tile to toggle WebUI server on/off

## How it works

- The tile runs `webui_server.sh toggle` as root
- Requires a root manager (Magisk, KernelSU, etc.) to grant `su` permission
- First tap may prompt for root permission
- Tile shows "WebUI ON" (active) or "WebUI OFF" (inactive)

## Notes

- This is a **helper app** — the main module must be installed first
- The app needs root access to toggle the server
- Works with all root managers (Magisk, KernelSU, APatch, etc.)
