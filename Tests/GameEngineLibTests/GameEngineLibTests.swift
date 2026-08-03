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
}
