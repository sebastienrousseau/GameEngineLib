import Foundation
import XCTest
@testable import GameEngineLib

final class GameEngineLibTests: XCTestCase {
  func testSeededSpawnsAreReproducibleAndSafe() {
    var first = SpawnDirector(seed: 0xCAFE_BABE)
    var second = SpawnDirector(seed: 0xCAFE_BABE)
    for index in 0..<1_000 {
      let a = first.nextPlan(elapsedTime: Double(index), score: index * 10)
      let b = second.nextPlan(elapsedTime: Double(index), score: index * 10)
      XCTAssertEqual(a, b)
      XCTAssertTrue(0.05...0.95 ~= a.horizontalPosition)
      XCTAssertGreaterThan(a.speed, 0)
    }
  }

  func testEveryLaneBandIsUsedBeforeTheBagRepeats() {
    var director = SpawnDirector(seed: 73)
    let positions = (0..<7).map {
      director.nextPlan(elapsedTime: Double($0), score: 0).horizontalPosition
    }
    let laneWidth = 0.82 / 7.0
    let lanes = Set(positions.map { Int(($0 - 0.09) / laneWidth) })
    XCTAssertEqual(lanes.count, 7)
  }

  func testScoringInventoryAndExtraLives() {
    var session = GameSession()
    XCTAssertTrue(session.slicePumpkin())
    XCTAssertTrue(session.boomPumpkin())
    XCTAssertEqual(session.avoidPumpkin(), 5)
    XCTAssertEqual(session.score, 25)
    for _ in 0..<10 { session.collectSweet(kind: 2) }
    XCTAssertEqual(session.lives, 11)
  }

  func testComboWindow() {
    var combo = ComboTracker(window: 1.5)
    XCTAssertEqual(combo.registerHit(at: 1), ComboResult(count: 1, bonus: 0))
    XCTAssertEqual(combo.registerHit(at: 2), ComboResult(count: 2, bonus: 10))
    XCTAssertEqual(combo.registerHit(at: 5), ComboResult(count: 1, bonus: 0))
  }

  func testLeaderboardRanksAndCapsEntries() {
    var board = Leaderboard(capacity: 2)
    board.submit(LeaderboardEntry(playerName: "A", score: 100))
    board.submit(LeaderboardEntry(playerName: "B", score: 900))
    XCTAssertNil(board.submit(LeaderboardEntry(playerName: "C", score: 10)))
    XCTAssertEqual(board.entries.map(\.score), [900, 100])
  }

  func testSimulationIsDeterministicForSameSeedAndInputs() {
    var first = GameSimulation(seed: 42)
    var second = GameSimulation(seed: 42)
    for tick in 0..<1_000 {
      let actions: [InputAction]
      switch tick % 120 {
      case 0: actions = [.dash(x: 1, y: -0.3)]
      case 30: actions = [.shriek]
      default: actions = [.move(x: tick.isMultiple(of: 2) ? 1 : -1, y: -0.2)]
      }
      XCTAssertEqual(first.step(InputFrame(actions: actions)), second.step(InputFrame(actions: actions)))
      XCTAssertEqual(first.state, second.state)
      XCTAssertEqual(first.digest, second.digest)
      if first.state.session.isGameOver { break }
    }
  }

  func testSimulationChangesForDifferentSeeds() {
    let first = GameSimulation(seed: 1)
    let second = GameSimulation(seed: 2)
    XCTAssertNotEqual(first.state.pumpkins, second.state.pumpkins)
    XCTAssertNotEqual(first.digest, second.digest)
  }

  func testMovementIsNormalizedAndBounded() {
    let configuration = SimulationConfiguration(targetPumpkinCount: 0)
    var simulation = GameSimulation(seed: 1, configuration: configuration)
    for _ in 0..<1_000 {
      _ = simulation.step(InputFrame(actions: [.move(x: 100, y: -100)]))
    }
    XCTAssertTrue(0.04...0.96 ~= simulation.state.ghost.position.x)
    XCTAssertTrue(0.06...0.94 ~= simulation.state.ghost.position.y)
  }

  func testDirectMovementIsBounded() {
    let configuration = SimulationConfiguration(targetPumpkinCount: 0)
    var simulation = GameSimulation(seed: 1, configuration: configuration)
    _ = simulation.step(InputFrame(actions: [.moveTo(x: -10, y: 12)]))
    XCTAssertEqual(simulation.state.ghost.position, Vector2(x: 0.04, y: 0.94))
  }

  func testPauseFreezesPhysicsButAcceptsResume() {
    var simulation = GameSimulation(seed: 7)
    let before = simulation.state.pumpkins
    XCTAssertEqual(simulation.step(InputFrame(actions: [.pause])), [.paused])
    for _ in 0..<10 { _ = simulation.step() }
    XCTAssertEqual(simulation.state.pumpkins, before)
    XCTAssertEqual(simulation.step(InputFrame(actions: [.resume])), [.resumed])
    _ = simulation.step()
    XCTAssertNotEqual(simulation.state.pumpkins, before)
  }

  func testDashDestroysCrossedPumpkinsAndUsesSliceInventory() {
    let configuration = SimulationConfiguration(
      targetPumpkinCount: 3,
      dashDistance: 1,
      dashCooldownTicks: 10,
      ghostRadius: 2
    )
    var simulation = GameSimulation(seed: 99, configuration: configuration)
    let slices = simulation.state.session.slices
    let events = simulation.step(InputFrame(actions: [.dash(x: 0, y: -1)]))
    let destroyed = events.filter {
      if case .destroyed = $0 { return true }
      return false
    }
    XCTAssertEqual(destroyed.count, 3)
    XCTAssertEqual(simulation.state.session.slices, slices - 3)
    XCTAssertEqual(simulation.state.pumpkins.count, 3, "Destroyed entities are replenished")
  }

  func testShriekConsumesOneChargeAndCanDestroyMultiplePumpkins() {
    let configuration = SimulationConfiguration(targetPumpkinCount: 4, shriekRadius: 2)
    var simulation = GameSimulation(seed: 8, configuration: configuration)
    let charges = simulation.state.session.booms
    let events = simulation.step(InputFrame(actions: [.shriek]))
    XCTAssertTrue(events.contains(.shrieked(origin: Vector2(x: 0.5, y: 0.82), destroyedCount: 4)))
    XCTAssertEqual(simulation.state.session.booms, charges - 1)
    XCTAssertGreaterThanOrEqual(simulation.state.session.score, 40)
  }

  func testReplayReproducesDigest() throws {
    var replay = GameReplay(seed: 0xBEEF, mode: .classicRaid)
    replay.record(.move(x: 1, y: 0), at: 1)
    replay.record(.dash(x: 0, y: -1), at: 30)
    replay.record(.pause, at: 60)
    replay.record(.resume, at: 90)
    replay.record(.shriek, at: 100)
    let first = try ReplayVerifier.run(replay, through: 300)
    let second = try ReplayVerifier.run(replay, through: 300)
    XCTAssertEqual(first, second)
  }

  func testReplayRejectsUnsupportedRulesVersion() {
    let replay = GameReplay(rulesVersion: 999, seed: 1, mode: .classicRaid)
    XCTAssertThrowsError(try ReplayVerifier.run(replay, through: 1)) {
      XCTAssertEqual($0 as? ReplayVerificationError, .unsupportedRulesVersion(999))
    }
  }

  func testReplayRoundTripsThroughJSON() throws {
    var replay = GameReplay(seed: 12, mode: .dailyHaunt)
    replay.record(.dash(x: 0.25, y: -0.8), at: 42)
    let encoded = try JSONEncoder().encode(replay)
    XCTAssertEqual(try JSONDecoder().decode(GameReplay.self, from: encoded), replay)
  }

  func testTenThousandSpawnPlansRemainInsideSafeHorizontalBounds() {
    for seed in UInt64(0)..<100 {
      var director = SpawnDirector(seed: seed)
      for index in 0..<100 {
        let plan = director.nextPlan(elapsedTime: Double(index), score: index * 100)
        XCTAssertTrue(0.05...0.95 ~= plan.horizontalPosition)
        XCTAssertGreaterThan(plan.speed, 0)
        XCTAssertGreaterThan(plan.scale, 0)
      }
    }
  }

  func testSimulationConfigurationSanitizesInvalidValues() {
    let configuration = SimulationConfiguration(
      ticksPerSecond: 0,
      targetPumpkinCount: -3,
      movementSpeed: -1,
      dashDistance: -1,
      dashCooldownTicks: -1,
      ghostRadius: 0,
      shriekRadius: -1,
      minimumReactionTicks: -1
    )
    XCTAssertEqual(configuration.ticksPerSecond, 1)
    XCTAssertEqual(configuration.targetPumpkinCount, 0)
    XCTAssertEqual(configuration.movementSpeed, 0)
    XCTAssertEqual(configuration.dashDistance, 0)
    XCTAssertEqual(configuration.dashCooldownTicks, 0)
    XCTAssertEqual(configuration.ghostRadius, 0.001)
    XCTAssertEqual(configuration.shriekRadius, 0)
    XCTAssertEqual(configuration.minimumReactionTicks, 0)
  }

  func testWaveCompositionIsDeterministicAndSafeAcrossSeeds() {
    for seed in UInt64(0)..<1_000 {
      var first = WaveComposer(seed: seed)
      var second = WaveComposer(seed: seed)
      for waveIndex in 0..<20 {
        let progress = Double(waveIndex) / 19
        let a = first.nextWave(progress: progress)
        let b = second.nextWave(progress: progress)
        XCTAssertEqual(a, b)
        XCTAssertTrue(WaveSafetyValidator.isSafe(a, reactionTicks: 8))
      }
    }
  }

  func testWaveValidatorRejectsBlockedReactionWindow() {
    let blocked = WavePlan(
      pattern: .stagger,
      spawns: (0..<WaveComposer.laneCount).map {
        WaveSpawn(lane: $0, delayTicks: 0, archetype: .standard)
      },
      restTicks: 10
    )
    XCTAssertFalse(WaveSafetyValidator.isSafe(blocked, reactionTicks: 1))
  }

  func testEarlyWavesUseAccessiblePatterns() {
    var composer = WaveComposer(seed: 11)
    for _ in 0..<30 {
      XCTAssertTrue([.stagger, .sweep, .breathingSpace].contains(composer.nextWave(progress: 0).pattern))
    }
  }
}
