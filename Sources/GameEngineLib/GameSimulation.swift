/// Authoritative, renderer-independent fixed-timestep game simulation.
public struct GameSimulation: Sendable {
  public static let rulesVersion = 2

  public private(set) var state: GameState
  public let configuration: SimulationConfiguration

  private var director: SpawnDirector
  private var waveComposer: WaveComposer
  private var comboTracker = ComboTracker()
  private var nextEntityID = 1
  private var emittedGameOver = false
  private var scheduledSpawns: [ScheduledSpawn] = []
  private var nextWaveTick: UInt64 = 0
  private var nextPickupTick: UInt64 = 0

  public init(
    seed: UInt64,
    mode: GameMode = .classicRaid,
    configuration: SimulationConfiguration = .standard
  ) {
    self.configuration = configuration
    director = SpawnDirector(seed: seed)
    waveComposer = WaveComposer(seed: seed)
    let remainingTicks = mode == .moonRush ? configuration.ticksPerSecond * 60 : nil
    state = GameState(
      rulesVersion: Self.rulesVersion,
      seed: seed,
      mode: mode,
      remainingTicks: remainingTicks
    )
    var initialEvents: [GameEvent] = []
    spawnToTarget(events: &initialEvents)
    nextPickupTick = UInt64(director.nextBonusDelay() * Double(configuration.ticksPerSecond))
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
      case .togglePause:
        state.isPaused.toggle()
        events.append(state.isPaused ? .paused : .resumed)
      default:
        break
      }
    }

    guard !state.isPaused, !state.isGameOver else {
      emitGameOverIfNeeded(into: &events)
      return events
    }

    let movement = frame.actions.compactMap { action -> Vector2? in
      if case .move(let x, let y) = action { return Vector2(x: x, y: y) }
      return nil
    }.last
    let directTarget = frame.actions.compactMap { action -> Vector2? in
      if case .moveTo(let x, let y) = action { return Vector2(x: x, y: y) }
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
      case .dash(let x, let y): performDash(Vector2(x: x, y: y), events: &events)
      case .shriek: performShriek(events: &events)
      case .slice(let from, let to): performSlice(from: from, to: to, events: &events)
      case .move, .moveTo, .pause, .resume, .togglePause: break
      }
    }

    advancePumpkins(events: &events)
    advancePickup(events: &events)
    if state.ghost.dashCooldownTicks > 0 { state.ghost.dashCooldownTicks -= 1 }
    if state.frenzyTicksRemaining > 0 { state.frenzyTicksRemaining -= 1 }
    updateRechargeTimers()
    updateModeTimer()
    scheduleWaveIfNeeded(events: &events)
    spawnScheduledPumpkins(events: &events)
    emitGameOverIfNeeded(into: &events)
    return events
  }

  /// Stable digest over quantized authoritative state. It intentionally avoids
  /// JSON encoding and floating-point byte layouts so Apple and Wasm can compare it.
  public var digest: UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    func append(_ value: UInt64) {
      hash ^= value
      hash &*= 0x100_0000_01b3
    }
    func quantized(_ value: Double) -> UInt64 {
      UInt64(bitPattern: Int64((value * 1_000_000).rounded()))
    }

    append(UInt64(state.rulesVersion))
    append(state.seed)
    append(UInt64(GameMode.allCases.firstIndex(of: state.mode)!))
    append(state.tick)
    append(state.isPaused ? 1 : 0)
    append(UInt64(state.session.score))
    append(UInt64(max(0, state.session.lives)))
    append(UInt64(state.session.slices))
    append(UInt64(state.session.booms))
    append(UInt64(state.statistics.destroyed))
    append(UInt64(state.statistics.avoided))
    append(UInt64(state.statistics.collisions))
    append(UInt64(state.statistics.nearMisses))
    append(UInt64(state.statistics.bestCombo))
    append(UInt64(state.waveIndex))
    append(UInt64(state.frenzyTicksRemaining))
    append(UInt64(state.remainingTicks ?? -1, bitPatternFallback: true))
    append(state.hasEnded ? 1 : 0)
    append(UInt64(state.sliceRechargeProgressTicks))
    append(UInt64(state.shriekRechargeProgressTicks))
    append(quantized(state.ghost.position.x))
    append(quantized(state.ghost.position.y))
    for pumpkin in state.pumpkins.sorted(by: { $0.id < $1.id }) {
      append(UInt64(pumpkin.id))
      append(UInt64(pumpkin.archetype.rawValue))
      append(UInt64(pumpkinKindIndex(pumpkin.kind)))
      append(UInt64(pumpkin.hitPoints))
      append(pumpkin.nearMissAwarded ? 1 : 0)
      append(quantized(pumpkin.position.x))
      append(quantized(pumpkin.position.y))
      append(quantized(pumpkin.velocity.x))
      append(quantized(pumpkin.velocity.y))
      append(quantized(pumpkin.radius))
    }
    if let pickup = state.pickup {
      append(1)
      append(UInt64(pickup.id))
      append(UInt64(pickup.kind))
      append(quantized(pickup.position.x))
      append(quantized(pickup.position.y))
      append(quantized(pickup.speed))
    } else {
      append(0)
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
      awardDestruction(id: id, events: &events)
    }
    events.append(.shrieked(origin: origin, destroyedCount: hitIDs.count))
  }

  private mutating func performSlice(
    from: Vector2,
    to: Vector2,
    events: inout [GameEvent]
  ) {
    let bladeTolerance = configuration.ghostRadius * 0.75 + 0.02
    let hitPumpkins = state.pumpkins.filter {
      distanceFromPoint($0.position, toSegmentFrom: from, to: to)
        <= $0.radius + bladeTolerance
    }
    for pumpkin in hitPumpkins {
      guard let index = state.pumpkins.firstIndex(where: { $0.id == pumpkin.id }) else { continue }
      if pumpkin.kind == .cursed {
        state.pumpkins.remove(at: index)
        if state.mode != .spiritZen { _ = state.session.collideWithPumpkin() }
        state.statistics.collisions += 1
        comboTracker.breakCombo()
        events.append(.cursedTriggered(id: pumpkin.id, remainingLives: state.session.lives))
        if state.session.lives == 1 { events.append(.lastChance) }
      } else if pumpkin.hitPoints > 1 {
        state.pumpkins[index].hitPoints -= 1
        events.append(
          .armoredHit(id: pumpkin.id, remainingHitPoints: state.pumpkins[index].hitPoints))
      } else {
        state.pumpkins.remove(at: index)
        awardDestruction(id: pumpkin.id, events: &events)
      }
    }

    if let pickup = state.pickup,
      distanceFromPoint(pickup.position, toSegmentFrom: from, to: to) <= 0.05
    {
      let points = state.session.collectSweet(kind: pickup.kind)
      state.pickup = nil
      events.append(.pickupCollected(id: pickup.id, kind: pickup.kind, points: points))
      scheduleNextPickup()
    }
  }

  private mutating func destroyWithSlices(ids: [Int], events: inout [GameEvent]) {
    for id in ids {
      guard let index = state.pumpkins.firstIndex(where: { $0.id == id }),
        state.session.useSliceCharge()
      else { continue }
      if state.pumpkins[index].kind == .cursed {
        state.pumpkins.remove(at: index)
        if state.mode != .spiritZen { _ = state.session.collideWithPumpkin() }
        state.statistics.collisions += 1
        comboTracker.breakCombo()
        events.append(.cursedTriggered(id: id, remainingLives: state.session.lives))
        if state.session.lives == 1 { events.append(.lastChance) }
      } else if state.pumpkins[index].hitPoints > 1 {
        state.pumpkins[index].hitPoints -= 1
        events.append(.armoredHit(id: id, remainingHitPoints: state.pumpkins[index].hitPoints))
      } else {
        state.pumpkins.remove(at: index)
        awardDestruction(id: id, events: &events)
      }
    }
  }

  private mutating func awardDestruction(id: Int, events: inout [GameEvent]) {
    let multiplier = state.frenzyTicksRemaining > 0 ? 2 : 1
    let base = state.session.awardBonus(GameRules.destroyedPumpkinScore * multiplier)
    let combo = comboTracker.registerHit(at: simulationTime)
    let bonus = state.session.awardBonus(combo.bonus * multiplier)
    state.statistics.destroyed += 1
    state.statistics.bestCombo = max(state.statistics.bestCombo, combo.count)
    events.append(.destroyed(id: id, combo: combo.count, points: base + bonus))
    if combo.count >= configuration.frenzyComboThreshold, state.frenzyTicksRemaining == 0 {
      state.frenzyTicksRemaining = configuration.frenzyDurationTicks
      events.append(.frenzyStarted(durationTicks: configuration.frenzyDurationTicks))
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
      let pumpkin = state.pumpkins[index]
      let collisionDistance = pumpkin.radius + configuration.ghostRadius
      let horizontalDistance = abs(pumpkin.position.x - state.ghost.position.x)
      if !pumpkin.nearMissAwarded,
        pumpkin.position.y >= state.ghost.position.y,
        horizontalDistance > collisionDistance,
        horizontalDistance <= collisionDistance + configuration.nearMissDistance
      {
        state.pumpkins[index].nearMissAwarded = true
        let points = state.session.awardBonus(15)
        state.statistics.nearMisses += 1
        events.append(.nearMiss(id: pumpkin.id, points: points))
      }
    }

    let collided = state.pumpkins.filter {
      distance($0.position, state.ghost.position)
        <= $0.radius + configuration.ghostRadius
    }.map(\.id)
    for id in collided {
      guard let index = state.pumpkins.firstIndex(where: { $0.id == id }) else { continue }
      state.pumpkins.remove(at: index)
      if state.mode == .spiritZen || state.session.collideWithPumpkin() {
        comboTracker.breakCombo()
        state.statistics.collisions += 1
        events.append(.damaged(id: id, remainingLives: state.session.lives))
        if state.session.lives == 1 { events.append(.lastChance) }
      }
    }

    let avoided = state.pumpkins.filter { $0.position.y - $0.radius > 1 }.map(\.id)
    for id in avoided {
      guard let index = state.pumpkins.firstIndex(where: { $0.id == id }) else { continue }
      state.pumpkins.remove(at: index)
      let points = state.session.avoidPumpkin()
      state.statistics.avoided += 1
      events.append(.avoided(id: id, points: points))
    }
  }

  private mutating func advancePickup(events: inout [GameEvent]) {
    let delta = 1 / Double(configuration.ticksPerSecond)
    if var pickup = state.pickup {
      pickup.position.y += pickup.speed * delta
      state.pickup = pickup
      if distance(pickup.position, state.ghost.position) <= configuration.ghostRadius + 0.035 {
        let points = state.session.collectSweet(kind: pickup.kind)
        state.pickup = nil
        events.append(.pickupCollected(id: pickup.id, kind: pickup.kind, points: points))
        scheduleNextPickup()
      } else if pickup.position.y > 1.08 {
        state.pickup = nil
        events.append(.pickupMissed(id: pickup.id))
        scheduleNextPickup()
      }
    } else if state.tick >= nextPickupTick {
      let kind = director.nextBonusKind(count: GameRules.sweetScores.count)
      let plan = director.nextPlan(elapsedTime: simulationTime, score: state.session.score)
      let pickup = PickupState(
        id: nextEntityID,
        kind: kind,
        position: Vector2(x: plan.horizontalPosition, y: -0.06),
        speed: 0.13
      )
      nextEntityID += 1
      state.pickup = pickup
      events.append(.pickupSpawned(id: pickup.id, kind: kind))
    }
  }

  private mutating func scheduleNextPickup() {
    let delay = director.nextBonusDelay() * Double(configuration.ticksPerSecond)
    nextPickupTick = state.tick + UInt64(delay)
  }

  private mutating func spawnToTarget(events: inout [GameEvent]) {
    while state.pumpkins.count < configuration.targetPumpkinCount {
      let plan = director.nextPlan(elapsedTime: simulationTime, score: state.session.score)
      let pumpkin = makePumpkin(plan: plan)
      state.pumpkins.append(pumpkin)
      events.append(.spawned(id: pumpkin.id, archetype: pumpkin.archetype))
    }
  }

  private mutating func emitGameOverIfNeeded(into events: inout [GameEvent]) {
    guard state.isGameOver, !emittedGameOver else { return }
    emittedGameOver = true
    events.append(.gameOver(score: state.session.score))
  }

  private var simulationTime: Double {
    Double(state.tick) / Double(configuration.ticksPerSecond)
  }

  private mutating func scheduleWaveIfNeeded(events: inout [GameEvent]) {
    guard state.pumpkins.count < configuration.targetPumpkinCount,
      scheduledSpawns.isEmpty,
      state.tick >= nextWaveTick
    else { return }
    let progress = min(1, max(simulationTime / 180, Double(state.session.score) / 30_000))
    let wave = waveComposer.nextWave(progress: progress)
    assert(
      WaveSafetyValidator.isSafe(
        wave,
        reactionTicks: max(1, configuration.minimumReactionTicks / 4)
      )
    )
    state.waveIndex += 1
    scheduledSpawns = wave.spawns.map {
      ScheduledSpawn(tick: state.tick + UInt64($0.delayTicks), spawn: $0)
    }
    nextWaveTick = state.tick + UInt64(wave.spawns.map(\.delayTicks).max()! + wave.restTicks)
    events.append(.waveStarted(index: state.waveIndex, pattern: wave.pattern))
  }

  private mutating func spawnScheduledPumpkins(events: inout [GameEvent]) {
    while state.pumpkins.count < configuration.targetPumpkinCount,
      let scheduled = scheduledSpawns.first,
      scheduled.tick <= state.tick
    {
      scheduledSpawns.removeFirst()
      let plan = director.nextPlan(elapsedTime: simulationTime, score: state.session.score)
      let laneWidth = 0.82 / Double(WaveComposer.laneCount)
      let horizontal = 0.09 + (Double(scheduled.spawn.lane) + 0.5) * laneWidth
      let adjusted = SpawnPlan(
        horizontalPosition: horizontal,
        verticalOffset: 0,
        speed: plan.speed,
        horizontalDrift: plan.horizontalDrift,
        scale: plan.scale,
        animationRate: plan.animationRate,
        archetype: scheduled.spawn.archetype
      )
      let pumpkin = makePumpkin(plan: adjusted)
      state.pumpkins.append(pumpkin)
      events.append(.spawned(id: pumpkin.id, archetype: pumpkin.archetype))
    }
  }

  private mutating func makePumpkin(plan: SpawnPlan) -> PumpkinState {
    let kind: PumpkinKind
    if plan.archetype == .heavy || (state.mode == .bossRaid && nextEntityID.isMultiple(of: 3)) {
      kind = .armored
    } else if state.tick > UInt64(configuration.ticksPerSecond * 20),
      nextEntityID.isMultiple(of: 11)
    {
      kind = .cursed
    } else {
      kind = .target
    }
    let pumpkin = PumpkinState(
      id: nextEntityID,
      position: Vector2(x: plan.horizontalPosition, y: -0.08 - plan.verticalOffset / 760),
      velocity: Vector2(
        x: plan.horizontalDrift / 320 * configuration.difficultyScale,
        y: plan.speed / 760 * configuration.difficultyScale
      ),
      radius: 0.04 * plan.scale,
      archetype: plan.archetype,
      kind: kind,
      hitPoints: kind == .armored ? 2 : 1
    )
    nextEntityID += 1
    return pumpkin
  }

  private mutating func updateModeTimer() {
    guard let remaining = state.remainingTicks, remaining > 0 else { return }
    state.remainingTicks = remaining - 1
    if state.remainingTicks == 0 { state.hasEnded = true }
  }

  private mutating func updateRechargeTimers() {
    state.sliceRechargeProgressTicks += 1
    state.shriekRechargeProgressTicks += 1
    if state.sliceRechargeProgressTicks >= configuration.sliceRechargeIntervalTicks {
      state.session.rechargeSlices()
      state.sliceRechargeProgressTicks = 0
    }
    if state.shriekRechargeProgressTicks >= configuration.shriekRechargeIntervalTicks {
      state.session.rechargeBooms()
      state.shriekRechargeProgressTicks = 0
    }
  }
}

private struct ScheduledSpawn: Sendable {
  let tick: UInt64
  let spawn: WaveSpawn
}

private func pumpkinKindIndex(_ kind: PumpkinKind) -> Int {
  switch kind {
  case .target: 0
  case .armored: 1
  case .cursed: 2
  }
}

extension UInt64 {
  fileprivate init(_ value: Int, bitPatternFallback: Bool) {
    self = bitPatternFallback ? UInt64(bitPattern: Int64(value)) : UInt64(value)
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

private func distanceFromPoint(_ point: Vector2, toSegmentFrom start: Vector2, to end: Vector2)
  -> Double
{
  let segment = Vector2(x: end.x - start.x, y: end.y - start.y)
  let lengthSquared = segment.x * segment.x + segment.y * segment.y
  guard lengthSquared > 0.000_000_1 else { return distance(point, start) }
  let projection =
    ((point.x - start.x) * segment.x + (point.y - start.y) * segment.y) / lengthSquared
  let t = min(1, max(0, projection))
  return distance(point, Vector2(x: start.x + segment.x * t, y: start.y + segment.y * t))
}
