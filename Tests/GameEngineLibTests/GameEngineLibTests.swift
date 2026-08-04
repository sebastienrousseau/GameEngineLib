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
      XCTAssertEqual(
        first.step(InputFrame(actions: actions)), second.step(InputFrame(actions: actions)))
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
    XCTAssertTrue(1...3 ~= simulation.state.pumpkins.count, "A paced wave begins after the clear")
    XCTAssertTrue(
      events.contains {
        if case .waveStarted = $0 { return true }
        return false
      })
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
      XCTAssertTrue(
        [.stagger, .sweep, .breathingSpace].contains(composer.nextWave(progress: 0).pattern))
    }
  }

  func testMoonRushEndsAfterSixtySimulationSeconds() {
    let configuration = SimulationConfiguration(ticksPerSecond: 1, targetPumpkinCount: 0)
    var simulation = GameSimulation(seed: 4, mode: .moonRush, configuration: configuration)
    for _ in 0..<59 { _ = simulation.step() }
    XCTAssertFalse(simulation.state.isGameOver)
    let events = simulation.step()
    XCTAssertTrue(simulation.state.isGameOver)
    XCTAssertTrue(events.contains(.gameOver(score: 0)))
  }

  func testSpiritZenCollisionsDoNotRemoveLives() {
    let configuration = SimulationConfiguration(targetPumpkinCount: 1, ghostRadius: 2)
    var simulation = GameSimulation(seed: 5, mode: .spiritZen, configuration: configuration)
    let lives = simulation.state.session.lives
    _ = simulation.step()
    XCTAssertEqual(simulation.state.session.lives, lives)
    XCTAssertEqual(simulation.state.statistics.collisions, 1)
    XCTAssertFalse(simulation.state.isGameOver)
  }

  func testUsingAChargeDoesNotAwardPointsUntilTargetIsDestroyed() {
    var session = GameSession()
    XCTAssertTrue(session.useSliceCharge())
    XCTAssertTrue(session.useBoomCharge())
    XCTAssertEqual(session.score, 0)
    XCTAssertEqual(session.slices, GameRules.initialSlices - 1)
    XCTAssertEqual(session.booms, GameRules.initialBooms - 1)
  }

  func testPickupLifecycleIsDeterministicAndAwardsConfiguredScore() {
    let configuration = SimulationConfiguration(
      ticksPerSecond: 1,
      targetPumpkinCount: 0,
      ghostRadius: 2
    )
    var simulation = GameSimulation(seed: 123, configuration: configuration)
    var events: [GameEvent] = []
    for _ in 0..<10 { events += simulation.step() }
    let collected = events.compactMap { event -> (Int, Int)? in
      if case .pickupCollected(_, let kind, let points) = event { return (kind, points) }
      return nil
    }
    XCTAssertFalse(collected.isEmpty)
    XCTAssertTrue(collected.allSatisfy { GameRules.sweetScores[$0.0] == $0.1 })
    XCTAssertGreaterThan(simulation.state.session.score, 0)
  }

  func testInventoryRechargeUsesSimulationTicks() {
    let configuration = SimulationConfiguration(
      targetPumpkinCount: 1,
      dashCooldownTicks: 0,
      ghostRadius: 2,
      sliceRechargeIntervalTicks: 2,
      shriekRechargeIntervalTicks: 3
    )
    var simulation = GameSimulation(seed: 1, configuration: configuration)
    _ = simulation.step(InputFrame(actions: [.dash(x: 1, y: 0), .shriek]))
    let spentSlices = simulation.state.session.slices
    let spentShrieks = simulation.state.session.booms
    _ = simulation.step()
    XCTAssertEqual(simulation.state.session.slices, min(GameRules.maximumSlices, spentSlices + 2))
    _ = simulation.step()
    XCTAssertEqual(simulation.state.session.booms, min(GameRules.maximumBooms, spentShrieks + 1))
  }

  func testOneHundredThousandGeneratedWavesRemainSafe() {
    for seed in UInt64(0)..<5_000 {
      var composer = WaveComposer(seed: seed)
      for index in 0..<20 {
        let wave = composer.nextWave(progress: Double(index) / 19)
        XCTAssertTrue(WaveSafetyValidator.isSafe(wave, reactionTicks: 8))
      }
    }
  }

  func testSemanticInputRouterNormalizesDigitalMovementAndEdgesActions() {
    var router = SemanticInputRouter()
    router.set(.right, pressed: true)
    router.set(.up, pressed: true)
    router.set(.dash, pressed: true)
    router.set(.dash, pressed: true)
    let first = router.nextFrame().actions
    XCTAssertEqual(first.count, 2)
    guard case .move(let x, let y) = first[0] else { return XCTFail("Expected movement") }
    XCTAssertEqual((x * x + y * y).squareRoot(), 1, accuracy: 0.000_001)
    XCTAssertEqual(first[1], .dash(x: x, y: y))
    XCTAssertEqual(router.nextFrame().actions, [.move(x: x, y: y)])
  }

  func testSemanticInputRouterSupportsDirectDragDashTapAndCancellation() {
    var router = SemanticInputRouter()
    router.beginPointer(at: Vector2(x: 0.2, y: 0.8), timestamp: 1, controlsGhost: true)
    router.movePointer(to: Vector2(x: 0.5, y: 0.5))
    XCTAssertEqual(router.nextFrame().actions, [.moveTo(x: 0.5, y: 0.5)])
    router.endPointer(at: Vector2(x: 0.5, y: 0.5), timestamp: 1.2)
    XCTAssertEqual(router.nextFrame().actions.count, 1)

    router.beginPointer(at: Vector2(x: 0.1, y: 0.1), timestamp: 2, controlsGhost: false)
    router.endPointer(at: Vector2(x: 0.1, y: 0.1), timestamp: 2.1)
    XCTAssertEqual(router.nextFrame().actions, [.shriek])
    router.set(.left, pressed: true)
    router.cancelAll()
    XCTAssertTrue(router.nextFrame().actions.isEmpty)
  }

  func testTogglePauseIsSymmetric() {
    let configuration = SimulationConfiguration(targetPumpkinCount: 0)
    var simulation = GameSimulation(seed: 1, configuration: configuration)
    XCTAssertEqual(simulation.step(InputFrame(actions: [.togglePause])), [.paused])
    XCTAssertEqual(simulation.step(InputFrame(actions: [.togglePause])), [.resumed])
  }

  func testBossRaidStartsWithArmoredTargets() {
    let simulation = GameSimulation(seed: 1, mode: .bossRaid)
    XCTAssertTrue(simulation.state.pumpkins.contains(where: { $0.kind == .armored }))
  }

  func testSettingsDecodeLegacyPayloadWithAccessibleDefaults() throws {
    let data = Data(
      "{\"musicEnabled\":false,\"effectsEnabled\":true,\"vibrationEnabled\":false}".utf8)
    let settings = try JSONDecoder().decode(GameSettings.self, from: data)
    XCTAssertFalse(settings.musicEnabled)
    XCTAssertTrue(settings.captionsEnabled)
    XCTAssertFalse(settings.reducedMotionEnabled)
    XCTAssertTrue(settings.screenShakeEnabled)
    XCTAssertEqual(settings.inputSensitivity, 1)
  }

  func testSettingsClampInputSensitivity() {
    XCTAssertEqual(GameSettings(inputSensitivity: -4).inputSensitivity, 0.5)
    XCTAssertEqual(GameSettings(inputSensitivity: 9).inputSensitivity, 1.5)
  }

  func testProgressionAwardsGoalsUnlocksAndPerModeBestScores() {
    var progress = PlayerProgress(experience: 480)
    let summary = RunSummary(
      mode: .moonRush,
      score: 5_000,
      statistics: SessionStatistics(destroyed: 30, nearMisses: 6, bestCombo: 9),
      durationTicks: 3_600,
      replayDigest: 42,
      assisted: false
    )
    let update = ProgressionSystem.apply(summary, to: &progress)
    XCTAssertGreaterThanOrEqual(progress.level, 2)
    XCTAssertEqual(progress.bestScores[.moonRush], 5_000)
    XCTAssertTrue(update.isNewBest)
    XCTAssertFalse(update.completedMissionIDs.isEmpty)
    XCTAssertTrue(progress.unlockedCosmeticIDs.contains("trail.ember"))
  }
}
