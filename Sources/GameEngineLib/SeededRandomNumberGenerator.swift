/// A reproducible SplitMix64 generator for gameplay systems and tests.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
  private var state: UInt64
  public init(seed: UInt64) { state = seed }

  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }

  /// Uses an explicitly 64-bit denominator. `Int` is 32-bit on wasm32, where
  /// evaluating `1 << 53` traps before the value can be converted to `Double`.
  public mutating func unitInterval() -> Double {
    Double(next() >> 11) / Double(UInt64(1) << 53)
  }
  public mutating func value(in range: ClosedRange<Double>) -> Double {
    range.lowerBound + unitInterval() * (range.upperBound - range.lowerBound)
  }
  public mutating func integer(in range: Range<Int>) -> Int {
    precondition(!range.isEmpty)
    return range.lowerBound + Int(next() % UInt64(range.count))
  }
}
