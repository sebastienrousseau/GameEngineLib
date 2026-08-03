import Foundation

public struct GameSettings: Codable, Equatable, Sendable {
  public var musicEnabled = true
  public var effectsEnabled = true
  public var vibrationEnabled = true
  public init() {}
}
