<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

<h1 align="center">GameEngineLib</h1>

<p align="center">
  A deterministic, renderer-independent game engine written in pure Swift for Apple platforms, WebAssembly, and simulation servers.
</p>

<p align="center">
  <a href="https://github.com/sebastienrousseau/GameEngineLib/actions"><img src="https://img.shields.io/github/actions/workflow/status/sebastienrousseau/GameEngineLib/swift.yml?style=for-the-badge&logo=github" alt="Build" height="28" /></a>
  <a href="https://swift.org/package-manager/"><img src="https://img.shields.io/badge/SwiftPM-compatible-orange?style=for-the-badge&logo=swift" alt="SwiftPM" height="28" /></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/sebastienrousseau/GameEngineLib"><img src="https://img.shields.io/ossf-scorecard/github.com/sebastienrousseau/GameEngineLib?style=for-the-badge&label=OpenSSF%20Scorecard&logo=openssf" alt="OpenSSF Scorecard" height="28" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg?style=for-the-badge" alt="License: Apache-2.0 OR MIT" height="28" /></a>
  <a href="Package.swift"><img src="https://img.shields.io/badge/Swift-6.0+-93450a.svg?style=for-the-badge&logo=swift" alt="Swift 6.0+" height="28" /></a>
</p>

---

## Contents

**Getting started**

- [Install](#install) - Swift Package Manager dependency
- [Requirements](#requirements) - toolchain floor and supported platforms
- [Quick Start](#quick-start) - initializing and stepping simulations

**Library reference**

- [Capabilities at a glance](#capabilities-at-a-glance) - core simulation features
- [Deterministic Architecture](#deterministic-architecture) - fixed timestep and state digests
- [Game Modes](#game-modes) - supported arcade modes

**Operational**

- [When not to use GameEngineLib](#when-not-to-use-gameenginelib) - limitations
- [Development](#development) - building and running tests
- [Security](#security) - reporting vulnerabilities
- [Documentation](#documentation) - reference guides
- [Stability guarantees](#stability-guarantees) - SemVer policy
- [License](#license) - Apache-2.0 OR MIT

---

## Install

### As a Swift Package

Add GameEngineLib to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/sebastienrousseau/GameEngineLib.git", from: "0.4.3")
]
```

Or add it directly in Xcode via **File > Add Packages...** using the repository URL.

---

## Requirements

- **Swift**: 6.0 or later
- **Xcode**: 16.0 or later
- **Supported platforms**:
  - macOS 14.0+
  - iOS 17.0+
  - tvOS 17.0+
  - WebAssembly (via SwiftWasm)
  - Linux server hosts

---

## Quick Start

```swift
import GameEngineLib

// Initialize simulation with a deterministic seed
var simulation = GameSimulation(seed: 42)

// Step simulation with semantic input actions
let events = simulation.step(
    InputFrame(actions: [.move(x: 1, y: 0), .dash(x: 0, y: -1)])
)

// Obtain verifiable state digest
let digest = simulation.digest
print("State digest: \(digest)")
```

---

## Capabilities at a glance

- **Zero Framework Coupling**: No dependencies on SwiftUI, SpriteKit, UIKit, or AppKit.
- **Deterministic Fixed-Timestep**: Identical input frame sequences produce bit-exact simulation digests.
- **Semantic Input Routing**: Normalizes digital movement, touches, mouse drags, and gamepad controls.
- **Wave Composition**: Procedural yet reproducible enemy wave generation with bounded horizontal limits.
- **Progression & Scoring**: Level tracking, missions, cosmetic unlocks, and local leaderboard ranking.

---

## Deterministic Architecture

Every run is uniquely defined by:
1. Rules version
2. Seed number
3. Ordered sequence of input frames

Because physics and simulation state updates are decoupled from frame rendering rates, competitive replay verification and multiplayer state synchronization are fully reproducible.

---

## Game Modes

GameEngineLib ships with five pre-configured arcade game modes:
- **Classic Raid**: Standard wave escalation with high-score progression.
- **Moon Rush**: Sixty-second score frenzy with rapid wave pacing.
- **Spirit Zen**: Relaxed mode with non-lethal obstacles.
- **Daily Haunt**: UTC daily challenge using synchronized seed generation.
- **Boss Raid**: Direct battle against high-durability targets.

---

## When not to use GameEngineLib

- **Heavy 3D Physics**: GameEngineLib provides 2D arcade physics; for 3D physics, consider RealityKit or Bullet.
- **Rendering Pipeline**: GameEngineLib calculates state only and delegates drawing to the host application.

---

## Development

```bash
# Build library targets
swift build

# Run deterministic test suite and soak tests
swift test
```

---

## Security

Report vulnerabilities according to [`SECURITY.md`](SECURITY.md).

---

## Documentation

- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Changelog](CHANGELOG.md)

---

## Stability guarantees

GameEngineLib adheres to [Semantic Versioning 2.0.0](https://semver.org/). Public API surfaces remain backward-compatible within major versions.

---

## License

Copyright © 2026 <a href="https://sebastienrousseau.com/" rel="author">Sebastien Rousseau</a>. All rights reserved.

Licensed under either the [Apache License, Version 2.0](LICENSE-APACHE) or the [MIT License](LICENSE-MIT) at your option.
