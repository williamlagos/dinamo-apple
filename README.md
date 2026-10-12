# Dinamo (Apple)

A native 80s arcade space shooter inspired by the classic **Galaga**, built with **Swift** and **SpriteKit** for **macOS**, **iOS**, and **tvOS**.

![Apple](https://img.shields.io/badge/Platforms-macOS%20%7C%20iOS%20%7C%20tvOS-black)
![SpriteKit](https://img.shields.io/badge/Framework-SpriteKit-blue)
![Swift](https://img.shields.io/badge/Language-Swift%205-orange)
![Xcode](https://img.shields.io/badge/Xcode-Multiplatform-blueviolet)

---

## Overview

Dinamo brings the authentic 1981 arcade shooter experience to Apple platforms with native performance:
- **Universal Multiplatform Architecture:** A single shared SpriteKit game scene (`GameScene.swift`) powers macOS, iOS, and tvOS targets with tailored input handling.
- **Zero Asset Dependencies:** Procedural retro pixel art is generated at runtime via CoreGraphics (`CGContext`) with nearest-neighbor texture filtering.
- **In-Memory Audio Synthesis:** 8-bit sound effects (lasers, dive swoops, explosions, player death) are synthesized programmatically in memory as PCM WAV buffers played through `AVAudioPlayer`.
- **Bézier Curved Flight Paths:** Smooth entrance loops, swoops, and dive-bomb paths driven natively by `CGPath` and `SKAction.follow`.
- **Fleet Formations & Dive Bombers:** Enemies assemble into a 40-alien grid formation that sways and flaps wings, with periodic dive bombers peeling off to attack the player.
- **Authentic Galaga Rules:** Twin laser missiles limited to a maximum of **2 on screen at once**, encouraging high accuracy.
- **Game Controller & Remote Support:** Works seamlessly with keyboard, mouse, touch, swipe gestures, Siri Remote, and connected Bluetooth controllers (Xbox, PlayStation, MFi).

---

## Controls

| Platform | Controls |
| :--- | :--- |
| **macOS** | • **Move:** `←` / `→` or `A` / `D`, or mouse drag<br>• **Fire:** `Spacebar` / `Return` / `↑` / Left Click<br>• **Restart:** `Spacebar` or Click |
| **iOS** | • **Move:** Touch and drag across bottom screen<br>• **Fire:** Tap screen<br>• **Swipe:** Quick lateral evasions |
| **tvOS** | • **Siri Remote:** Swipe / click directional pad to steer, click to fire<br>• **Game Controller:** D-Pad / Analog stick to move, `A` button to fire |

---

## Tech Stack

- **Framework:** Apple SpriteKit (`SKScene`, `SKSpriteNode`, `SKAction`, `SKShapeNode`)
- **Graphics Generation:** CoreGraphics (`CGContext`, `CGImage`)
- **Sound Generation:** AVFoundation (`AVAudioPlayer`, `AVAudioSession`)
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
