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

public enum GameMode: String, CaseIterable, Hashable, Codable, Sendable {
  case classicRaid
  case moonRush
  case spiritZen
  case dailyHaunt
  case bossRaid
}

public enum PumpkinKind: String, Codable, Sendable {
  case target
  case armored
  case cursed
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
  public let kind: PumpkinKind
  public var hitPoints: Int
  public var nearMissAwarded: Bool

  public init(
    id: Int,
    position: Vector2,
    velocity: Vector2,
    radius: Double,
    archetype: PumpkinArchetype,
    kind: PumpkinKind = .target,
    hitPoints: Int = 1,
    nearMissAwarded: Bool = false
  ) {
    self.id = id
    self.position = position
    self.velocity = velocity
    self.radius = radius
    self.archetype = archetype
    self.kind = kind
    self.hitPoints = max(1, hitPoints)
    self.nearMissAwarded = nearMissAwarded
  }
}

public struct PickupState: Identifiable, Equatable, Codable, Sendable {
  public let id: Int
  public let kind: Int
  public var position: Vector2
  public let speed: Double

  public init(id: Int, kind: Int, position: Vector2, speed: Double) {
    self.id = id
    self.kind = kind
    self.position = position
    self.speed = max(0, speed)
  }
}

public struct SessionStatistics: Equatable, Codable, Sendable {
  public var destroyed = 0
  public var avoided = 0
  public var collisions = 0
  public var nearMisses = 0
  public var bestCombo = 0

  public init(
    destroyed: Int = 0,
    avoided: Int = 0,
    collisions: Int = 0,
    nearMisses: Int = 0,
    bestCombo: Int = 0
  ) {
    self.destroyed = max(0, destroyed)
    self.avoided = max(0, avoided)
    self.collisions = max(0, collisions)
    self.nearMisses = max(0, nearMisses)
    self.bestCombo = max(0, bestCombo)
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
  public var pickup: PickupState?
  public var session: GameSession
  public var statistics: SessionStatistics
  public var waveIndex: Int
  public var frenzyTicksRemaining: Int
  public var remainingTicks: Int?
  public var hasEnded: Bool
  public var sliceRechargeProgressTicks: Int
  public var shriekRechargeProgressTicks: Int

  public init(
    rulesVersion: Int,
    seed: UInt64,
    mode: GameMode,
    tick: UInt64 = 0,
    isPaused: Bool = false,
    ghost: GhostState = GhostState(),
    pumpkins: [PumpkinState] = [],
    pickup: PickupState? = nil,
    session: GameSession = GameSession(),
    statistics: SessionStatistics = SessionStatistics(),
    waveIndex: Int = 0,
    frenzyTicksRemaining: Int = 0,
    remainingTicks: Int? = nil,
    hasEnded: Bool = false,
    sliceRechargeProgressTicks: Int = 0,
    shriekRechargeProgressTicks: Int = 0
  ) {
    self.rulesVersion = rulesVersion
    self.seed = seed
    self.mode = mode
    self.tick = tick
    self.isPaused = isPaused
    self.ghost = ghost
    self.pumpkins = pumpkins
    self.pickup = pickup
    self.session = session
    self.statistics = statistics
    self.waveIndex = max(0, waveIndex)
    self.frenzyTicksRemaining = max(0, frenzyTicksRemaining)
    self.remainingTicks = remainingTicks.map { max(0, $0) }
    self.hasEnded = hasEnded
    self.sliceRechargeProgressTicks = max(0, sliceRechargeProgressTicks)
    self.shriekRechargeProgressTicks = max(0, shriekRechargeProgressTicks)
  }

  public var isGameOver: Bool { hasEnded || session.isGameOver }
}

public enum GameEvent: Equatable, Codable, Sendable {
  case spawned(id: Int, archetype: PumpkinArchetype)
  case avoided(id: Int, points: Int)
  case damaged(id: Int, remainingLives: Int)
  case dashed(from: Vector2, to: Vector2)
  case destroyed(id: Int, combo: Int, points: Int)
  case armoredHit(id: Int, remainingHitPoints: Int)
  case cursedTriggered(id: Int, remainingLives: Int)
  case nearMiss(id: Int, points: Int)
  case pickupSpawned(id: Int, kind: Int)
  case pickupCollected(id: Int, kind: Int, points: Int)
  case pickupMissed(id: Int)
  case waveStarted(index: Int, pattern: WavePattern)
  case frenzyStarted(durationTicks: Int)
  case lastChance
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
  public var nearMissDistance: Double
  public var frenzyComboThreshold: Int
  public var frenzyDurationTicks: Int
  public var sliceRechargeIntervalTicks: Int
  public var shriekRechargeIntervalTicks: Int
  public var difficultyScale: Double

  public init(
    ticksPerSecond: Int = 60,
    targetPumpkinCount: Int = GameRules.enemyCount,
    movementSpeed: Double = 0.72,
    dashDistance: Double = 0.28,
    dashCooldownTicks: Int = 24,
    ghostRadius: Double = 0.04,
    shriekRadius: Double = 0.26,
    minimumReactionTicks: Int = 36,
    nearMissDistance: Double = 0.035,
    frenzyComboThreshold: Int = 6,
    frenzyDurationTicks: Int = 360,
    sliceRechargeIntervalTicks: Int = 360,
    shriekRechargeIntervalTicks: Int = 180,
    difficultyScale: Double = 1
  ) {
    self.ticksPerSecond = max(1, ticksPerSecond)
    self.targetPumpkinCount = max(0, targetPumpkinCount)
    self.movementSpeed = max(0, movementSpeed)
    self.dashDistance = max(0, dashDistance)
    self.dashCooldownTicks = max(0, dashCooldownTicks)
    self.ghostRadius = max(0.001, ghostRadius)
    self.shriekRadius = max(0, shriekRadius)
    self.minimumReactionTicks = max(0, minimumReactionTicks)
    self.nearMissDistance = max(0, nearMissDistance)
    self.frenzyComboThreshold = max(2, frenzyComboThreshold)
    self.frenzyDurationTicks = max(1, frenzyDurationTicks)
    self.sliceRechargeIntervalTicks = max(1, sliceRechargeIntervalTicks)
    self.shriekRechargeIntervalTicks = max(1, shriekRechargeIntervalTicks)
    self.difficultyScale = min(1.5, max(0.5, difficultyScale))
  }

  public static let standard = SimulationConfiguration()
}
