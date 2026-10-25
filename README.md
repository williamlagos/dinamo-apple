# Dinamo (Apple)

A native retro arcade and Game Boy space shooter inspired by the classic **Galaga**, built with **Swift** and **SpriteKit** for **macOS**, **iOS**, and **tvOS**.

![Game Boy](https://img.shields.io/badge/Game%20Boy-160x144-88c070)
![Apple](https://img.shields.io/badge/Platforms-macOS%20%7C%20iOS%20%7C%20tvOS-black)
![SpriteKit](https://img.shields.io/badge/Framework-SpriteKit-blue)
![Swift](https://img.shields.io/badge/Language-Swift%205-orange)
![Xcode](https://img.shields.io/badge/Xcode-Multiplatform-blueviolet)

---

## Overview

Dinamo brings the authentic 160×144 retro Game Boy look and feel to Apple ecosystems with native metal-accelerated SpriteKit performance:
- **Unified 160×144 Game Boy Viewport:** Exact 10:9 aspect ratio (`CGSize(width: 160, height: 144)`) rendered integer-scaled and centered via `scaleMode = .aspectFit` without faux plastic frames or bezels.
- **Multiple Authentic 4-Color Palettes:**
  - **DMG (1989):** Dot-matrix pea-green monochrome LCD (`#e0f8d0`, `#88c070`, `#346856`, `#081820`).
  - **POCKET (1996):** Film-compensated true monochrome FSTN LCD (`#ffffff`, `#aaaaaa`, `#555555`, `#000000`).
  - **GBC (1998):** Colorized sprite banks with dark navy space background.
  - **ARCADE (1981):** Original full-color Galaga arcade aesthetics.
- **Dynamic Palette Switching:** Switch themes on the fly via keys `1`-`4` or `T` on macOS, tapping the HUD or swiping on iOS, or pressing button `X` on game controllers.
- **Shared Assets:** Sprites, starfields, and palette specifications shared with `gbgame`, `web`, and `android`.
- **In-Memory Chiptune Sound Engine:** Synthesizes Game Boy pulse waves with frequency sweeps (laser, dive) and 7-bit LFSR pseudo-random noise for authentic crashes and explosions.
- **10-Ship Tactical Armada:** Formation breathing, synchronized 2-frame wing flapping, and dive-bomb sweeps matching the GB Studio project.
- **Authentic Combat Rules:** Strict 2-missile on-screen limitation true to retro hardware.

---

## Controls

| Platform | Controls |
| :--- | :--- |
| **macOS** | • **Move:** `←` / `→` or `A` / `D`, or mouse drag<br>• **Fire:** `Spacebar` / `Return` / `↑` / Left Click<br>• **Switch Palette:** Keys `1` (DMG), `2` (Pocket), `3` (GBC), `4` (Arcade), or `T` (Cycle)<br>• **Restart:** `Spacebar` or Click on Game Over |
| **iOS** | • **Move:** Touch and drag across bottom rank<br>• **Fire:** Tap screen<br>• **Switch Palette:** Tap top HUD bar or swipe vertically<br>• **Swipe:** Quick lateral evasions |
| **tvOS** | • **Siri Remote:** Swipe / click directional pad to steer, click to fire<br>• **Game Controller:** D-Pad / Analog stick to move, `A` button to fire, `X` button to switch theme |

---

## Tech Stack

- **Framework:** Apple SpriteKit (`SKScene`, `SKSpriteNode`, `SKAction`, `SKShapeNode`)
- **Graphics Generation:** CoreGraphics (`CGContext`, `CGImage`) with nearest-neighbor texture filtering
- **Sound Generation:** AVFoundation (`AVAudioPlayer`, `AVAudioSession`) with pulse waveforms & 7-bit LFSR noise
- **Controllers:** GameController framework (`GCController`, `GCExtendedGamepad`)

---

## Getting Started

1. Open the project in Xcode:
   ```bash
   open Dinamo/Dinamo.xcodeproj
   ```

2. Select your desired scheme from the top toolbar:
   - `Dinamo macOS`
   - `Dinamo iOS`
   - `Dinamo tvOS`

3. Select your run destination (My Mac, iOS Simulator, or Apple TV Simulator) and press **⌘R** (Run).
