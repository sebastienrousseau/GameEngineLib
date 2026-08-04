public struct RunSummary: Equatable, Codable, Sendable {
  public let mode: GameMode
  public let score: Int
  public let statistics: SessionStatistics
  public let durationTicks: UInt64
  public let replayDigest: UInt64
  public let assisted: Bool

  public init(
    mode: GameMode,
    score: Int,
    statistics: SessionStatistics,
    durationTicks: UInt64,
    replayDigest: UInt64,
    assisted: Bool
  ) {
    self.mode = mode
    self.score = max(0, score)
    self.statistics = statistics
    self.durationTicks = durationTicks
    self.replayDigest = replayDigest
    self.assisted = assisted
  }
}

public enum MissionMetric: String, Codable, Sendable {
  case score
  case pumpkinsDestroyed
  case nearMisses
  case bestCombo
  case runsCompleted
}

public struct MissionDefinition: Identifiable, Equatable, Codable, Sendable {
  public let id: String
  public let title: String
  public let metric: MissionMetric
  public let target: Int
  public let rewardEctoplasm: Int

  public init(id: String, title: String, metric: MissionMetric, target: Int, rewardEctoplasm: Int) {
    self.id = id
    self.title = title
    self.metric = metric
    self.target = max(1, target)
    self.rewardEctoplasm = max(0, rewardEctoplasm)
  }
}

public struct MissionStatus: Identifiable, Equatable, Codable, Sendable {
  public let id: String
  public var progress: Int
  public var isClaimed: Bool

  public init(id: String, progress: Int = 0, isClaimed: Bool = false) {
    self.id = id
    self.progress = max(0, progress)
    self.isClaimed = isClaimed
  }
}

public struct CosmeticItem: Identifiable, Equatable, Codable, Sendable {
  public enum Category: String, Codable, Sendable { case ghost, trail, aura }

  public let id: String
  public let name: String
  public let category: Category
  public let unlockLevel: Int

  public init(id: String, name: String, category: Category, unlockLevel: Int) {
    self.id = id
    self.name = name
    self.category = category
    self.unlockLevel = max(1, unlockLevel)
  }
}

public struct PlayerProgress: Equatable, Codable, Sendable {
  public var experience: Int
  public var ectoplasm: Int
  public var totalRuns: Int
  public var bestScores: [GameMode: Int]
  public var unlockedCosmeticIDs: Set<String>
  public var equippedGhostID: String
  public var equippedTrailID: String
  public var missionStatuses: [MissionStatus]

  public init(
    experience: Int = 0,
    ectoplasm: Int = 0,
    totalRuns: Int = 0,
    bestScores: [GameMode: Int] = [:],
    unlockedCosmeticIDs: Set<String> = ["ghost.classic", "trail.moonlight"],
    equippedGhostID: String = "ghost.classic",
    equippedTrailID: String = "trail.moonlight",
    missionStatuses: [MissionStatus] = ProgressionCatalog.missions.map { MissionStatus(id: $0.id) }
  ) {
    self.experience = max(0, experience)
    self.ectoplasm = max(0, ectoplasm)
    self.totalRuns = max(0, totalRuns)
    self.bestScores = bestScores
    self.unlockedCosmeticIDs = unlockedCosmeticIDs
    self.equippedGhostID = equippedGhostID
    self.equippedTrailID = equippedTrailID
    self.missionStatuses = missionStatuses
  }

  public var level: Int { 1 + experience / 500 }
  public var experienceWithinLevel: Int { experience % 500 }
}

public struct ProgressionUpdate: Equatable, Codable, Sendable {
  public let experienceAwarded: Int
  public let ectoplasmAwarded: Int
  public let levelsGained: Int
  public let newlyUnlockedCosmeticIDs: [String]
  public let completedMissionIDs: [String]
  public let isNewBest: Bool
}

public enum ProgressionCatalog {
  public static let missions = [
    MissionDefinition(
      id: "mission.destroy.25",
      title: "Dash through 25 pumpkins",
      metric: .pumpkinsDestroyed,
      target: 25,
      rewardEctoplasm: 100
    ),
    MissionDefinition(
      id: "mission.near.5",
      title: "Thread 5 near misses",
      metric: .nearMisses,
      target: 5,
      rewardEctoplasm: 125
    ),
    MissionDefinition(
      id: "mission.combo.8",
      title: "Reach an 8-hit combo",
      metric: .bestCombo,
      target: 8,
      rewardEctoplasm: 150
    ),
    MissionDefinition(
      id: "mission.score.5000",
      title: "Score 5,000 in one raid",
      metric: .score,
      target: 5_000,
      rewardEctoplasm: 200
    ),
    MissionDefinition(
      id: "mission.runs.10",
      title: "Complete 10 raids",
      metric: .runsCompleted,
      target: 10,
      rewardEctoplasm: 250
    ),
  ]

  public static let cosmetics = [
    CosmeticItem(id: "ghost.classic", name: "Moon Ghost", category: .ghost, unlockLevel: 1),
    CosmeticItem(id: "trail.moonlight", name: "Moonlight", category: .trail, unlockLevel: 1),
    CosmeticItem(id: "trail.ember", name: "Pumpkin Ember", category: .trail, unlockLevel: 2),
    CosmeticItem(id: "ghost.frost", name: "Frost Phantom", category: .ghost, unlockLevel: 3),
    CosmeticItem(id: "aura.frenzy", name: "Frenzy Aura", category: .aura, unlockLevel: 4),
    CosmeticItem(id: "trail.cursed", name: "Cursed Wake", category: .trail, unlockLevel: 5),
    CosmeticItem(id: "ghost.king", name: "Ghost King", category: .ghost, unlockLevel: 7),
  ]
}

public enum ProgressionSystem {
  @discardableResult
  public static func apply(_ summary: RunSummary, to progress: inout PlayerProgress)
    -> ProgressionUpdate
  {
    let previousLevel = progress.level
    let previousBest = progress.bestScores[summary.mode] ?? 0
    let experience = max(20, summary.score / 20 + summary.statistics.destroyed * 2)
    let ectoplasm = max(5, summary.statistics.destroyed + summary.statistics.nearMisses * 3)
    progress.experience += experience
    progress.ectoplasm += ectoplasm
    progress.totalRuns += 1
    progress.bestScores[summary.mode] = max(previousBest, summary.score)

    var completed: [String] = []
    for definition in ProgressionCatalog.missions {
      guard let index = progress.missionStatuses.firstIndex(where: { $0.id == definition.id }),
        !progress.missionStatuses[index].isClaimed
      else { continue }
      let increment: Int
      switch definition.metric {
      case .score: increment = summary.score
      case .pumpkinsDestroyed: increment = summary.statistics.destroyed
      case .nearMisses: increment = summary.statistics.nearMisses
      case .bestCombo: increment = summary.statistics.bestCombo
      case .runsCompleted: increment = 1
      }
      if definition.metric == .score || definition.metric == .bestCombo {
        progress.missionStatuses[index].progress = max(
          progress.missionStatuses[index].progress,
          increment
        )
      } else {
        progress.missionStatuses[index].progress += increment
      }
      if progress.missionStatuses[index].progress >= definition.target {
        progress.missionStatuses[index].isClaimed = true
        progress.ectoplasm += definition.rewardEctoplasm
        completed.append(definition.id)
      }
    }

    let unlocks = ProgressionCatalog.cosmetics.filter {
      $0.unlockLevel <= progress.level && !progress.unlockedCosmeticIDs.contains($0.id)
    }.map(\.id)
    progress.unlockedCosmeticIDs.formUnion(unlocks)
    return ProgressionUpdate(
      experienceAwarded: experience,
      ectoplasmAwarded: ectoplasm,
      levelsGained: progress.level - previousLevel,
      newlyUnlockedCosmeticIDs: unlocks,
      completedMissionIDs: completed,
      isNewBest: summary.score > previousBest
    )
  }
}
