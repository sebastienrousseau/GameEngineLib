# GameEngineLib

[![Swift](https://img.shields.io/badge/Swift-6.2-F05138.svg)](https://swift.org)
[![CI](https://github.com/sebastienrousseau/GameEngineLib/actions/workflows/swift.yml/badge.svg)](https://github.com/sebastienrousseau/GameEngineLib/actions)

A reusable, renderer-independent game engine written in pure Swift. It provides
a deterministic fixed-timestep simulation, semantic input, replay verification,
authored wave composition, fair spawning, five arcade modes, target roles,
pickups, scoring, combo/frenzy tracking, settings, and local leaderboard ranking.

`GameEngineLib` has no dependency on SwiftUI, SpriteKit, UIKit, AppKit, or game assets.
It can be used by Apple, WebAssembly, server, and simulation targets.

## Installation

Add the package to `Package.swift`:

```swift
.package(url: "https://github.com/sebastienrousseau/GameEngineLib.git", from: "0.3.0")
```

Then add `GameEngineLib` to the target dependencies.

## Example

```swift
import GameEngineLib

var simulation = GameSimulation(seed: 42)
let events = simulation.step(
  InputFrame(actions: [.move(x: 1, y: 0), .dash(x: 0, y: -1)])
)
let verifiableDigest = simulation.digest
```

The same rules version, seed, and semantic input stream produce the same quantized
state digest, making balancing, automated testing, replay, Web parity, and
competitive-score verification practical.

## Development

```sh
swift build
swift test
```

Licensed under the zlib license. See [LICENSE.txt](LICENSE.txt).
