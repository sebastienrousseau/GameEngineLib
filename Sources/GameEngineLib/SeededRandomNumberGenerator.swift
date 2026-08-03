/// A reproducible SplitMix64 generator for gameplay systems and tests.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
  private var state: UInt64
  public init(seed: UInt64) { state = seed }

  public mutating func next() -> UInt64 {
    state &+= 0x9E3779B97F4A7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
    value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
    return value ^ (value >> 31)
  }

  public mutating func unitInterval() -> Double { Double(next() >> 11) / Double(1 << 53) }
  public mutating func value(in range: ClosedRange<Double>) -> Double {
    range.lowerBound + unitInterval() * (range.upperBound - range.lowerBound)
  }
  public mutating func integer(in range: Range<Int>) -> Int {
    precondition(!range.isEmpty)
    return range.lowerBound + Int(next() % UInt64(range.count))
  }
}
