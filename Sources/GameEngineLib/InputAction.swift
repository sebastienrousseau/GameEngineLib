/// Renderer-independent player intent. Platform hosts translate physical input
/// into these actions before it reaches the simulation.
public enum InputAction: Equatable, Codable, Sendable {
  /// Continuous normalized movement intent. Each component is clamped to -1...1.
  case move(x: Double, y: Double)
  /// Direct normalized playfield target used by touch, pointer, and motion hosts.
  case moveTo(x: Double, y: Double)
  /// A continuous touch or pointer sword slice segment from start to end.
  case slice(from: Vector2, to: Vector2)
  /// A discrete normalized dash vector.
  case dash(x: Double, y: Double)
  /// Spend a charge to destroy threats around the ghost.
  case shriek
  case pause
  case resume
  case togglePause
}

public enum DigitalControl: Hashable, Sendable {
  case left
  case right
  case up
  case down
  case dash
  case shriek
  case pause
}

/// Converts keyboard, controller, remote, pointer, and touch state into the same
/// semantic action frames. Platform code only maps physical controls to this API.
public struct SemanticInputRouter: Sendable {
  private var pressed: Set<DigitalControl> = []
  private var pending: [InputAction] = []
  private var directTarget: Vector2?
  private var pointerStart: Vector2?
  private var pointerStartedAt = 0.0
  private var pointerControlsGhost = false

  public init() {}

  public mutating func set(_ control: DigitalControl, pressed isPressed: Bool) {
    let wasPressed = pressed.contains(control)
    if isPressed { pressed.insert(control) } else { pressed.remove(control) }
    guard isPressed, !wasPressed else { return }
    switch control {
    case .dash:
      let direction = movementDirection
      pending.append(.dash(x: direction.x, y: direction.length > 0 ? direction.y : -1))
    case .shriek: pending.append(.shriek)
    case .pause: pending.append(.togglePause)
    case .left, .right, .up, .down: break
    }
  }

  public mutating func enqueue(_ action: InputAction) {
    pending.append(action)
  }

  public mutating func slice(from: Vector2, to: Vector2) {
    pending.append(.slice(from: from, to: to))
  }

  public mutating func beginPointer(
    at point: Vector2,
    timestamp: Double,
    controlsGhost: Bool
  ) {
    pointerStart = point
    pointerStartedAt = timestamp
    pointerControlsGhost = controlsGhost
    directTarget = controlsGhost ? point : nil
  }

  public mutating func movePointer(to point: Vector2) {
    guard pointerStart != nil, pointerControlsGhost else { return }
    directTarget = point
  }

  public mutating func endPointer(at point: Vector2, timestamp: Double) {
    defer {
      pointerStart = nil
      directTarget = nil
      pointerControlsGhost = false
    }
    guard let start = pointerStart else { return }
    let delta = Vector2(x: point.x - start.x, y: point.y - start.y)
    let duration = max(0, timestamp - pointerStartedAt)
    if delta.length >= 0.08, duration <= 0.55 {
      let direction = delta.normalized()
      pending.append(.dash(x: direction.x, y: direction.y))
    } else if !pointerControlsGhost || delta.length < 0.035 {
      pending.append(.shriek)
    }
  }

  public mutating func cancelAll() {
    pressed.removeAll()
    pending.removeAll(keepingCapacity: true)
    pointerStart = nil
    directTarget = nil
    pointerControlsGhost = false
  }

  public mutating func nextFrame() -> InputFrame {
    var actions: [InputAction] = []
    let direction = movementDirection
    if direction.length > 0 { actions.append(.move(x: direction.x, y: direction.y)) }
    if let directTarget { actions.append(.moveTo(x: directTarget.x, y: directTarget.y)) }
    actions.append(contentsOf: pending)
    pending.removeAll(keepingCapacity: true)
    return InputFrame(actions: actions)
  }

  private var movementDirection: Vector2 {
    let x = Double((pressed.contains(.right) ? 1 : 0) - (pressed.contains(.left) ? 1 : 0))
    let y = Double((pressed.contains(.down) ? 1 : 0) - (pressed.contains(.up) ? 1 : 0))
    return Vector2(x: x, y: y).normalized()
  }
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
