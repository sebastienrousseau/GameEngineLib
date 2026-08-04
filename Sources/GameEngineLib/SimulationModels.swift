public struct Vector2: Equatable, Codable, Sendable {
  public var x: Double
  public var y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }

  public static let zero = Vector2(x: 0, y: 0)

  public var length: Double { (x * x + y * y).squareRoot() }

  public func normalized(or fallback: Vector2 = .zero) -> Vector2 {
    let magnitude = length
    guard magnitude > 0.000_001 else { return fallback }
    return Vector2(x: x / magnitude, y: y / magnitude)
  }
}

public enum GameMode: String, CaseIterable, Codable, Sendable {
  case classicRaid
  case moonRush
  case spiritZen
  case dailyHaunt
  case bossRaid
}

public struct GhostState: Equatable, Codable, Sendable {
  public var position: Vector2
  public var dashCooldownTicks: Int

  public init(position: Vector2 = Vector2(x: 0.5, y: 0.82), dashCooldownTicks: Int = 0) {
    self.position = position
    self.dashCooldownTicks = max(0, dashCooldownTicks)
  }
}

public struct PumpkinState: Identifiable, Equatable, Codable, Sendable {
  public let id: Int
  public var position: Vector2
  public var velocity: Vector2
  public let radius: Double
  public let archetype: PumpkinArchetype

  public init(
    id: Int,
    position: Vector2,
    velocity: Vector2,
    radius: Double,
    archetype: PumpkinArchetype
  ) {
    self.id = id
    self.position = position
    self.velocity = velocity
    self.radius = radius
    self.archetype = archetype
  }
}

public struct GameState: Equatable, Codable, Sendable {
  public let rulesVersion: Int
  public let seed: UInt64
  public let mode: GameMode
  public var tick: UInt64
  public var isPaused: Bool
  public var ghost: GhostState
  public var pumpkins: [PumpkinState]
  public var session: GameSession

  public init(
    rulesVersion: Int,
    seed: UInt64,
    mode: GameMode,
    tick: UInt64 = 0,
    isPaused: Bool = false,
    ghost: GhostState = GhostState(),
    pumpkins: [PumpkinState] = [],
    session: GameSession = GameSession()
  ) {
    self.rulesVersion = rulesVersion
    self.seed = seed
    self.mode = mode
    self.tick = tick
    self.isPaused = isPaused
    self.ghost = ghost
    self.pumpkins = pumpkins
    self.session = session
  }
}

public enum GameEvent: Equatable, Codable, Sendable {
  case spawned(id: Int, archetype: PumpkinArchetype)
  case avoided(id: Int, points: Int)
  case damaged(id: Int, remainingLives: Int)
  case dashed(from: Vector2, to: Vector2)
  case destroyed(id: Int, combo: Int, points: Int)
  case shrieked(origin: Vector2, destroyedCount: Int)
  case paused
  case resumed
  case gameOver(score: Int)
}

public struct SimulationConfiguration: Equatable, Codable, Sendable {
  public var ticksPerSecond: Int
  public var targetPumpkinCount: Int
  public var movementSpeed: Double
  public var dashDistance: Double
  public var dashCooldownTicks: Int
  public var ghostRadius: Double
  public var shriekRadius: Double
  public var minimumReactionTicks: Int

  public init(
    ticksPerSecond: Int = 60,
    targetPumpkinCount: Int = GameRules.enemyCount,
    movementSpeed: Double = 0.72,
    dashDistance: Double = 0.28,
    dashCooldownTicks: Int = 24,
    ghostRadius: Double = 0.04,
    shriekRadius: Double = 0.26,
    minimumReactionTicks: Int = 36
  ) {
    self.ticksPerSecond = max(1, ticksPerSecond)
    self.targetPumpkinCount = max(0, targetPumpkinCount)
    self.movementSpeed = max(0, movementSpeed)
    self.dashDistance = max(0, dashDistance)
    self.dashCooldownTicks = max(0, dashCooldownTicks)
    self.ghostRadius = max(0.001, ghostRadius)
    self.shriekRadius = max(0, shriekRadius)
    self.minimumReactionTicks = max(0, minimumReactionTicks)
  }

  public static let standard = SimulationConfiguration()
}
