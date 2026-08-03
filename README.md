# GameEngineLib

[![Swift](https://img.shields.io/badge/Swift-6.2-F05138.svg)](https://swift.org)
[![CI](https://github.com/sebastienrousseau/GameEngineLib/actions/workflows/swift.yml/badge.svg)](https://github.com/sebastienrousseau/GameEngineLib/actions)

A reusable, renderer-independent game engine written in pure Swift. It provides
deterministic random generation, fair spawn direction, scoring and inventory rules,
combo tracking, settings models, and local leaderboard ranking.

`GameEngineLib` has no dependency on SwiftUI, SpriteKit, UIKit, AppKit, or game assets.
It can be used by Apple, WebAssembly, server, and simulation targets.

## Installation

Add the package to `Package.swift`:

```swift
.package(url: "https://github.com/sebastienrousseau/GameEngineLib.git", from: "0.1.0")
```

Then add `GameEngineLib` to the target dependencies.

## Example

```swift
import GameEngineLib

var director = SpawnDirector(seed: 42)
let plan = director.nextPlan(elapsedTime: 15, score: 800)

var session = GameSession()
session.avoidPumpkin()
```

The same seed and inputs always produce the same spawn sequence, making balancing,
automated testing, telemetry replay, and multiplayer verification practical.

## Development

```sh
swift build
swift test
```

Licensed under the zlib license. See [LICENSE.txt](LICENSE.txt).
