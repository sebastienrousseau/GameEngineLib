public struct GameReplay: Equatable, Codable, Sendable {
  public let rulesVersion: Int
  public let seed: UInt64
  public let mode: GameMode
  public private(set) var commands: [InputCommand]

  public init(
    rulesVersion: Int = GameSimulation.rulesVersion,
    seed: UInt64,
    mode: GameMode,
    commands: [InputCommand] = []
  ) {
    self.rulesVersion = rulesVersion
    self.seed = seed
    self.mode = mode
    self.commands = commands.sorted { $0.tick < $1.tick }
  }

  public mutating func record(_ action: InputAction, at tick: UInt64) {
    commands.append(InputCommand(tick: tick, action: action))
  }
}

public enum ReplayVerificationError: Error, Equatable, Sendable {
  case unsupportedRulesVersion(Int)
  case commandOrder
}

public struct ReplayResult: Equatable, Codable, Sendable {
  public let finalState: GameState
  public let digest: UInt64
}

public enum ReplayVerifier {
  public static func run(
    _ replay: GameReplay,
    through finalTick: UInt64,
    configuration: SimulationConfiguration = .standard
  ) throws -> ReplayResult {
    guard replay.rulesVersion == GameSimulation.rulesVersion else {
      throw ReplayVerificationError.unsupportedRulesVersion(replay.rulesVersion)
    }
    guard zip(replay.commands, replay.commands.dropFirst()).allSatisfy({ $0.tick <= $1.tick }) else {
      throw ReplayVerificationError.commandOrder
    }

    var simulation = GameSimulation(
      seed: replay.seed,
      mode: replay.mode,
      configuration: configuration
    )
    var commandIndex = 0
    while simulation.state.tick < finalTick, !simulation.state.session.isGameOver {
      let nextTick = simulation.state.tick + 1
      var actions: [InputAction] = []
      while commandIndex < replay.commands.count, replay.commands[commandIndex].tick == nextTick {
        actions.append(replay.commands[commandIndex].action)
        commandIndex += 1
      }
      _ = simulation.step(InputFrame(actions: actions))
    }
    return ReplayResult(finalState: simulation.state, digest: simulation.digest)
  }
}
