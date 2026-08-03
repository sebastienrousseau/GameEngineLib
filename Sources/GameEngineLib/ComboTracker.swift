public struct ComboResult: Equatable, Sendable {
  public let count: Int
  public let bonus: Int
}

public struct ComboTracker: Equatable, Sendable {
  public private(set) var count = 0
  public let window: Double
  private var lastHitTime: Double?

  public init(window: Double = 1.8) { self.window = window }

  public mutating func registerHit(at time: Double) -> ComboResult {
    if let lastHitTime, time - lastHitTime <= window { count += 1 } else { count = 1 }
    lastHitTime = time
    return ComboResult(count: count, bonus: count >= 2 ? min(count, 10) * 5 : 0)
  }

  public mutating func breakCombo() {
    count = 0
    lastHitTime = nil
  }
}
