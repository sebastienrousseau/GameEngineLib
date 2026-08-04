public enum WavePattern: String, CaseIterable, Codable, Sendable {
  case stagger
  case sweep
  case pincer
  case zigzag
  case breathingSpace
}

public struct WaveSpawn: Equatable, Codable, Sendable {
  public let lane: Int
  public let delayTicks: Int
  public let archetype: PumpkinArchetype

  public init(lane: Int, delayTicks: Int, archetype: PumpkinArchetype) {
    self.lane = lane
    self.delayTicks = max(0, delayTicks)
    self.archetype = archetype
  }
}

public struct WavePlan: Equatable, Codable, Sendable {
  public let pattern: WavePattern
  public let spawns: [WaveSpawn]
  public let restTicks: Int

  public init(pattern: WavePattern, spawns: [WaveSpawn], restTicks: Int) {
    self.pattern = pattern
    self.spawns = spawns.sorted {
      if $0.delayTicks != $1.delayTicks { return $0.delayTicks < $1.delayTicks }
      return $0.lane < $1.lane
    }
    self.restTicks = max(0, restTicks)
  }
}

/// Produces rhythmic, authored-feeling formations while retaining seeded variety.
public struct WaveComposer: Sendable {
  public static let laneCount = 7

  private var random: SeededRandomNumberGenerator
  private var patternBag: [WavePattern] = []
  private var previousPattern: WavePattern?

  public init(seed: UInt64) {
    random = SeededRandomNumberGenerator(seed: seed ^ 0x5741_5645_434F_4D50)
  }

  public mutating func nextWave(progress rawProgress: Double) -> WavePlan {
    let progress = min(1, max(0, rawProgress))
    let pattern = nextPattern(progress: progress)
    let interval = max(12, Int(34 - progress * 16))
    let rest = max(24, Int(82 - progress * 34))
    let direction = random.integer(in: 0..<2) == 0 ? 1 : -1
    let archetype: (Int) -> PumpkinArchetype = { index in
      if progress > 0.65, index.isMultiple(of: 4) { return .heavy }
      if progress > 0.35, index.isMultiple(of: 3) { return .swift }
      if progress > 0.15, index.isMultiple(of: 2) { return .drifting }
      return .standard
    }

    let spawns: [WaveSpawn]
    switch pattern {
    case .stagger:
      let count = 3 + Int(progress * 3)
      var lanes = Array(0..<Self.laneCount)
      shuffle(&lanes)
      spawns = lanes.prefix(count).enumerated().map {
        WaveSpawn(lane: $0.element, delayTicks: $0.offset * interval, archetype: archetype($0.offset))
      }
    case .sweep:
      spawns = (0..<Self.laneCount).map { index in
        let lane = direction > 0 ? index : Self.laneCount - 1 - index
        return WaveSpawn(lane: lane, delayTicks: index * interval, archetype: archetype(index))
      }
    case .pincer:
      let pairs = progress > 0.55 ? 3 : 2
      spawns = (0..<pairs).flatMap { index in
        [
          WaveSpawn(lane: index, delayTicks: index * interval, archetype: archetype(index)),
          WaveSpawn(
            lane: Self.laneCount - 1 - index,
            delayTicks: index * interval,
            archetype: archetype(index + 1)
          ),
        ]
      }
    case .zigzag:
      let lanes = direction > 0 ? [0, 2, 4, 6, 4, 2] : [6, 4, 2, 0, 2, 4]
      spawns = lanes.enumerated().map {
        WaveSpawn(lane: $0.element, delayTicks: $0.offset * interval, archetype: archetype($0.offset))
      }
    case .breathingSpace:
      spawns = [
        WaveSpawn(lane: random.integer(in: 1..<6), delayTicks: 0, archetype: .standard)
      ]
    }
    return WavePlan(pattern: pattern, spawns: spawns, restTicks: rest)
  }

  private mutating func nextPattern(progress: Double) -> WavePattern {
    if patternBag.isEmpty {
      var refill = progress < 0.15
        ? [.stagger, .sweep, .breathingSpace]
        : WavePattern.allCases
      shuffle(&refill)
      if refill.last == previousPattern,
        let replacement = refill.firstIndex(where: { $0 != previousPattern })
      {
        refill.swapAt(replacement, refill.count - 1)
      }
      patternBag = refill
    }
    let pattern = patternBag.removeLast()
    previousPattern = pattern
    return pattern
  }

  private mutating func shuffle<T>(_ values: inout [T]) {
    guard values.count > 1 else { return }
    for index in stride(from: values.count - 1, through: 1, by: -1) {
      values.swapAt(index, random.integer(in: 0..<(index + 1)))
    }
  }
}

public enum WaveSafetyValidator {
  /// Ensures lanes are valid and every reaction window leaves at least one route.
  public static func isSafe(
    _ wave: WavePlan,
    laneCount: Int = WaveComposer.laneCount,
    reactionTicks: Int
  ) -> Bool {
    guard laneCount > 1, reactionTicks >= 0,
      wave.spawns.allSatisfy({ (0..<laneCount).contains($0.lane) })
    else { return false }

    for spawn in wave.spawns {
      let occupied = Set(wave.spawns.lazy.filter {
        abs($0.delayTicks - spawn.delayTicks) <= reactionTicks
      }.map(\.lane))
      if occupied.count >= laneCount { return false }
    }
    return true
  }
}
