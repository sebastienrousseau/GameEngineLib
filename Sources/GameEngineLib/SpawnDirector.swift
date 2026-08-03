public enum PumpkinArchetype: Int, CaseIterable, Codable, Sendable {
  case standard, swift, drifting, heavy
}

public struct SpawnPlan: Equatable, Codable, Sendable {
  public let horizontalPosition: Double
  public let verticalOffset: Double
  public let speed: Double
  public let horizontalDrift: Double
  public let scale: Double
  public let animationRate: Double
  public let archetype: PumpkinArchetype

  public init(horizontalPosition: Double, verticalOffset: Double, speed: Double,
    horizontalDrift: Double, scale: Double, animationRate: Double,
    archetype: PumpkinArchetype) {
    self.horizontalPosition = horizontalPosition
    self.verticalOffset = verticalOffset
    self.speed = speed
    self.horizontalDrift = horizontalDrift
    self.scale = scale
    self.animationRate = animationRate
    self.archetype = archetype
  }
}

/// Produces fair, unpredictable spawns without repeating the same screen lane.
public struct SpawnDirector: Sendable {
  private var random: SeededRandomNumberGenerator
  private var previousLane: Int?
  private let laneCount = 7

  public init(seed: UInt64) { random = SeededRandomNumberGenerator(seed: seed) }

  public mutating func nextPlan(elapsedTime: Double, score: Int) -> SpawnPlan {
    let progress = min(1, max(elapsedTime / 150, Double(score) / 25_000))
    var lane = random.integer(in: 0..<laneCount)
    if lane == previousLane {
      lane = (lane + 1 + random.integer(in: 0..<(laneCount - 1))) % laneCount
    }
    previousLane = lane
    let laneWidth = 0.82 / Double(laneCount)
    let jitter = random.value(in: (-laneWidth * 0.32)...(laneWidth * 0.32))
    let horizontal = 0.09 + (Double(lane) + 0.5) * laneWidth + jitter
    let archetype = chooseArchetype(progress: progress)
    let baseSpeed = random.value(in: 78...126) * (1 + progress * 0.72)
    let attributes: (speed: Double, drift: Double, scale: Double)
    switch archetype {
    case .standard: attributes = (baseSpeed, random.value(in: -12...12), random.value(in: 0.92...1.08))
    case .swift: attributes = (baseSpeed * 1.32, random.value(in: -18...18), random.value(in: 0.78...0.94))
    case .drifting: attributes = (baseSpeed * 0.92, random.value(in: -48...48), random.value(in: 0.9...1.05))
    case .heavy: attributes = (baseSpeed * 0.78, random.value(in: -8...8), random.value(in: 1.1...1.28))
    }
    return SpawnPlan(horizontalPosition: horizontal,
      verticalOffset: random.value(in: 0...210), speed: attributes.speed,
      horizontalDrift: attributes.drift, scale: attributes.scale,
      animationRate: random.value(in: 0.12...0.23), archetype: archetype)
  }

  private mutating func chooseArchetype(progress: Double) -> PumpkinArchetype {
    let roll = random.unitInterval()
    if progress > 0.25, roll < 0.18 { return .swift }
    if progress > 0.12, roll < 0.38 { return .drifting }
    if progress > 0.45, roll < 0.51 { return .heavy }
    return .standard
  }

  public mutating func nextBonusDelay() -> Double { random.value(in: 2.6...6.2) }
  public mutating func nextBonusKind(count: Int) -> Int { random.integer(in: 0..<count) }
  public mutating func particleVelocity() -> (x: Double, y: Double) {
    (random.value(in: -85...85), random.value(in: -70...105))
  }
}
