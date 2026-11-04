<div align="center">

# 🛠️ SimTools

**Simulator controls Xcode no longer shows, one click away in your menu bar.**

![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

</div>

---

Newer Xcode versions dropped **Shake** and **Slow Animations** from the Simulator UI. SimTools brings them back, along with a few other handy tools, in a tiny native menu bar app.

## Features

| | Feature | What it does |
|---|---|---|
| 📱 | **Simulator picker** | Choose which booted simulator every action targets |
| 📳 | **Shake** | Sends a shake gesture (`motionEnded` / `onShake`) |
| 🐢 | **Slow Animations** | Toggles UIKit slow-motion animations, with live on/off state |
| 🔗 | **Open URL** | Opens a deep link or web URL (prefilled from the clipboard) |
| 📍 | **Location** | Sets a preset city or custom coordinate, or clears the location |
| ⚡ | **Launch at Login** | Starts SimTools automatically when you log in |

## Install

```bash
git clone https://github.com/ewjinx/SimTools.git
cd SimTools
./build.sh
```

`build.sh` compiles SimTools, installs it to `~/Applications/SimTools.app` and launches it. It needs no Xcode project and no dependencies.

**Requirements:** macOS 13+ and Xcode (for `swiftc` and `simctl`).

## How it works

Each action wraps a standard `simctl` command:

```bash
# Shake
xcrun simctl spawn <udid> notifyutil -p com.apple.UIKit.SimulatorShake

# Slow Animations (1 = on, 0 = off)
xcrun simctl spawn <udid> notifyutil -s com.apple.UIKit.SimulatorSlowMotionAnimationState 1 \
                                     -p com.apple.UIKit.SimulatorSlowMotionAnimationState

# Open URL / Location
xcrun simctl openurl <udid> myapp://path
xcrun simctl location <udid> set 25.1972,55.2744
```

## License

[MIT](LICENSE)
