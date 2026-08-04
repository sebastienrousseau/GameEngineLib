/// Renderer-independent player intent. Platform hosts translate physical input
/// into these actions before it reaches the simulation.
public enum InputAction: Equatable, Codable, Sendable {
  /// Continuous normalized movement intent. Each component is clamped to -1...1.
  case move(x: Double, y: Double)
  /// Direct normalized playfield target used by touch, pointer, and motion hosts.
  case moveTo(x: Double, y: Double)
  /// A discrete normalized dash vector.
  case dash(x: Double, y: Double)
  /// Spend a charge to destroy threats around the ghost.
  case shriek
  case pause
  case resume
}

public struct InputCommand: Equatable, Codable, Sendable {
  public let tick: UInt64
  public let action: InputAction

  public init(tick: UInt64, action: InputAction) {
    self.tick = tick
    self.action = action
  }
}

public struct InputFrame: Equatable, Codable, Sendable {
  public let actions: [InputAction]

  public init(actions: [InputAction] = []) {
    self.actions = actions
  }
}
