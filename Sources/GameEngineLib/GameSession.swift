public struct GameSession: Equatable, Sendable {
  public private(set) var score = 0
  public private(set) var lives = GameRules.initialLives
  public private(set) var slices = GameRules.initialSlices
  public private(set) var booms = GameRules.initialBooms
  public private(set) var pointsTowardExtraLife = 0

  public init() {}
  public var isGameOver: Bool { lives <= 0 }

  @discardableResult public mutating func avoidPumpkin() -> Int {
    addScore(GameRules.avoidedPumpkinScore)
  }

  @discardableResult public mutating func collideWithPumpkin() -> Bool {
    guard !isGameOver else { return false }
    lives -= 1
    return true
  }

  @discardableResult public mutating func slicePumpkin() -> Bool {
    guard slices > 0, !isGameOver else { return false }
    slices -= 1
    addScore(GameRules.destroyedPumpkinScore)
    return true
  }

  @discardableResult public mutating func boomPumpkin() -> Bool {
    guard booms > 0, !isGameOver else { return false }
    booms -= 1
    addScore(GameRules.destroyedPumpkinScore)
    return true
  }

  @discardableResult public mutating func collectSweet(kind: Int) -> Int {
    guard GameRules.sweetScores.indices.contains(kind), !isGameOver else { return 0 }
    return addScore(GameRules.sweetScores[kind])
  }

  @discardableResult public mutating func awardBonus(_ points: Int) -> Int {
    guard !isGameOver else { return 0 }
    return addScore(points)
  }

  public mutating func rechargeSlices(_ amount: Int = 2) {
    slices = min(GameRules.maximumSlices, slices + max(0, amount))
  }

  public mutating func rechargeBooms(_ amount: Int = 1) {
    booms = min(GameRules.maximumBooms, booms + max(0, amount))
  }

  @discardableResult private mutating func addScore(_ points: Int) -> Int {
    guard points > 0 else { return 0 }
    score += points
    pointsTowardExtraLife += points
    while pointsTowardExtraLife >= GameRules.pointsPerExtraLife {
      lives += 1
      pointsTowardExtraLife -= GameRules.pointsPerExtraLife
    }
    return points
  }
}
