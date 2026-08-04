/// Authoritative, renderer-independent fixed-timestep game simulation.
public struct GameSimulation: Sendable {
  public static let rulesVersion = 1

  public private(set) var state: GameState
  public let configuration: SimulationConfiguration

  private var director: SpawnDirector
  private var comboTracker = ComboTracker()
  private var nextEntityID = 1
  private var emittedGameOver = false

  public init(
    seed: UInt64,
    mode: GameMode = .classicRaid,
    configuration: SimulationConfiguration = .standard
  ) {
    self.configuration = configuration
    director = SpawnDirector(seed: seed)
    state = GameState(rulesVersion: Self.rulesVersion, seed: seed, mode: mode)
    var initialEvents: [GameEvent] = []
    spawnToTarget(events: &initialEvents)
  }

  /// Advances exactly one simulation tick. Display refresh rate and window size
  /// must never be passed into this method.
  @discardableResult
  public mutating func step(_ frame: InputFrame = InputFrame()) -> [GameEvent] {
    state.tick &+= 1
    var events: [GameEvent] = []

    for action in frame.actions {
      switch action {
      case .pause where !state.isPaused:
        state.isPaused = true
        events.append(.paused)
      case .resume where state.isPaused:
        state.isPaused = false
        events.append(.resumed)
      default:
        break
      }
    }

    guard !state.isPaused, !state.session.isGameOver else {
      emitGameOverIfNeeded(into: &events)
      return events
    }

    let movement = frame.actions.compactMap { action -> Vector2? in
      if case let .move(x, y) = action { return Vector2(x: x, y: y) }
      return nil
    }.last
    let directTarget = frame.actions.compactMap { action -> Vector2? in
      if case let .moveTo(x, y) = action { return Vector2(x: x, y: y) }
      return nil
    }.last
    if let directTarget {
      state.ghost.position = Vector2(
        x: bounded(directTarget.x, 0.04...0.96),
        y: bounded(directTarget.y, 0.06...0.94)
      )
    }
    if let movement { moveGhost(movement) }

    for action in frame.actions {
      switch action {
      case let .dash(x, y): performDash(Vector2(x: x, y: y), events: &events)
      case .shriek: performShriek(events: &events)
      case .move, .moveTo, .pause, .resume: break
      }
    }

    advancePumpkins(events: &events)
    if state.ghost.dashCooldownTicks > 0 { state.ghost.dashCooldownTicks -= 1 }
    spawnToTarget(events: &events)
    emitGameOverIfNeeded(into: &events)
    return events
  }

  /// Stable digest over quantized authoritative state. It intentionally avoids
  /// JSON encoding and floating-point byte layouts so Apple and Wasm can compare it.
  public var digest: UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    func append(_ value: UInt64) {
      hash ^= value
      hash &*= 0x100000001b3
    }
    func quantized(_ value: Double) -> UInt64 {
      UInt64(bitPattern: Int64((value * 1_000_000).rounded()))
    }

    append(UInt64(state.rulesVersion))
    append(state.seed)
    append(UInt64(GameMode.allCases.firstIndex(of: state.mode) ?? 0))
    append(state.tick)
    append(state.isPaused ? 1 : 0)
    append(UInt64(state.session.score))
    append(UInt64(max(0, state.session.lives)))
    append(UInt64(state.session.slices))
    append(UInt64(state.session.booms))
    append(quantized(state.ghost.position.x))
    append(quantized(state.ghost.position.y))
    for pumpkin in state.pumpkins.sorted(by: { $0.id < $1.id }) {
      append(UInt64(pumpkin.id))
      append(UInt64(pumpkin.archetype.rawValue))
      append(quantized(pumpkin.position.x))
      append(quantized(pumpkin.position.y))
      append(quantized(pumpkin.velocity.x))
      append(quantized(pumpkin.velocity.y))
      append(quantized(pumpkin.radius))
    }
    return hash
  }

  private mutating func moveGhost(_ rawIntent: Vector2) {
    let clamped = Vector2(
      x: min(1, max(-1, rawIntent.x)),
      y: min(1, max(-1, rawIntent.y))
    )
    let direction = clamped.length > 1 ? clamped.normalized() : clamped
    let delta = configuration.movementSpeed / Double(configuration.ticksPerSecond)
    state.ghost.position.x = bounded(state.ghost.position.x + direction.x * delta, 0.04...0.96)
    state.ghost.position.y = bounded(state.ghost.position.y + direction.y * delta, 0.06...0.94)
  }

  private mutating func performDash(_ rawDirection: Vector2, events: inout [GameEvent]) {
    guard state.ghost.dashCooldownTicks == 0 else { return }
    let direction = rawDirection.normalized()
    guard direction.length > 0 else { return }
    let from = state.ghost.position
    let to = Vector2(
      x: bounded(from.x + direction.x * configuration.dashDistance, 0.04...0.96),
      y: bounded(from.y + direction.y * configuration.dashDistance, 0.06...0.94)
    )
    state.ghost.position = to
    state.ghost.dashCooldownTicks = configuration.dashCooldownTicks
    events.append(.dashed(from: from, to: to))

    let hitIDs = state.pumpkins.filter {
      distanceFromPoint($0.position, toSegmentFrom: from, to: to)
        <= $0.radius + configuration.ghostRadius * 0.55
    }.map(\.id)
    destroyWithSlices(ids: hitIDs, events: &events)
  }

  private mutating func performShriek(events: inout [GameEvent]) {
    guard state.session.useBoomCharge() else { return }
    let origin = state.ghost.position
    let hitIDs = state.pumpkins.filter {
      distance($0.position, origin) <= configuration.shriekRadius + $0.radius
    }.map(\.id)
    for id in hitIDs {
      guard let index = state.pumpkins.firstIndex(where: { $0.id == id }) else { continue }
      state.pumpkins.remove(at: index)
      let base = state.session.awardBonus(GameRules.destroyedPumpkinScore)
      let combo = comboTracker.registerHit(at: simulationTime)
      let bonus = state.session.awardBonus(combo.bonus)
      events.append(.destroyed(id: id, combo: combo.count, points: base + bonus))
    }
    events.append(.shrieked(origin: origin, destroyedCount: hitIDs.count))
  }

  private mutating func destroyWithSlices(ids: [Int], events: inout [GameEvent]) {
    for id in ids {
      guard let index = state.pumpkins.firstIndex(where: { $0.id == id }),
        state.session.slicePumpkin()
      else { continue }
      state.pumpkins.remove(at: index)
      let combo = comboTracker.registerHit(at: simulationTime)
      let bonus = state.session.awardBonus(combo.bonus)
      events.append(
        .destroyed(
          id: id,
          combo: combo.count,
          points: GameRules.destroyedPumpkinScore + bonus
        ))
    }
  }

  private mutating func advancePumpkins(events: inout [GameEvent]) {
    let delta = 1 / Double(configuration.ticksPerSecond)
    for index in state.pumpkins.indices {
      state.pumpkins[index].position.x += state.pumpkins[index].velocity.x * delta
      state.pumpkins[index].position.y += state.pumpkins[index].velocity.y * delta
      if state.pumpkins[index].position.x < 0.03 || state.pumpkins[index].position.x > 0.97 {
        state.pumpkins[index].velocity.x *= -1
        state.pumpkins[index].position.x = bounded(state.pumpkins[index].position.x, 0.03...0.97)
      }
    }

    let collided = state.pumpkins.filter {
      distance($0.position, state.ghost.position)
        <= $0.radius + configuration.ghostRadius
    }.map(\.id)
    for id in collided {
      guard let index = state.pumpkins.firstIndex(where: { $0.id == id }) else { continue }
      state.pumpkins.remove(at: index)
      if state.session.collideWithPumpkin() {
        comboTracker.breakCombo()
        events.append(.damaged(id: id, remainingLives: state.session.lives))
      }
    }

    let avoided = state.pumpkins.filter { $0.position.y - $0.radius > 1 }.map(\.id)
    for id in avoided {
      guard let index = state.pumpkins.firstIndex(where: { $0.id == id }) else { continue }
      state.pumpkins.remove(at: index)
      let points = state.session.avoidPumpkin()
      events.append(.avoided(id: id, points: points))
    }
  }

  private mutating func spawnToTarget(events: inout [GameEvent]) {
    while state.pumpkins.count < configuration.targetPumpkinCount {
      let plan = director.nextPlan(elapsedTime: simulationTime, score: state.session.score)
      let pumpkin = PumpkinState(
        id: nextEntityID,
        position: Vector2(x: plan.horizontalPosition, y: -0.08 - plan.verticalOffset / 760),
        velocity: Vector2(x: plan.horizontalDrift / 320, y: plan.speed / 760),
        radius: 0.04 * plan.scale,
        archetype: plan.archetype
      )
      nextEntityID += 1
      state.pumpkins.append(pumpkin)
      events.append(.spawned(id: pumpkin.id, archetype: pumpkin.archetype))
    }
  }

  private mutating func emitGameOverIfNeeded(into events: inout [GameEvent]) {
    guard state.session.isGameOver, !emittedGameOver else { return }
    emittedGameOver = true
    events.append(.gameOver(score: state.session.score))
  }

  private var simulationTime: Double {
    Double(state.tick) / Double(configuration.ticksPerSecond)
  }
}

private func bounded(_ value: Double, _ range: ClosedRange<Double>) -> Double {
  min(range.upperBound, max(range.lowerBound, value))
}

private func distance(_ lhs: Vector2, _ rhs: Vector2) -> Double {
  let dx = lhs.x - rhs.x
  let dy = lhs.y - rhs.y
  return (dx * dx + dy * dy).squareRoot()
}

private func distanceFromPoint(_ point: Vector2, toSegmentFrom start: Vector2, to end: Vector2) -> Double {
  let segment = Vector2(x: end.x - start.x, y: end.y - start.y)
  let lengthSquared = segment.x * segment.x + segment.y * segment.y
  guard lengthSquared > 0.000_000_1 else { return distance(point, start) }
  let projection = ((point.x - start.x) * segment.x + (point.y - start.y) * segment.y) / lengthSquared
  let t = min(1, max(0, projection))
  return distance(point, Vector2(x: start.x + segment.x * t, y: start.y + segment.y * t))
}
