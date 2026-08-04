import Foundation

public struct GameSettings: Codable, Equatable, Sendable {
  public var musicEnabled: Bool
  public var effectsEnabled: Bool
  public var vibrationEnabled: Bool
  public var captionsEnabled: Bool
  public var reducedMotionEnabled: Bool
  public var screenShakeEnabled: Bool
  public var highContrastEnabled: Bool
  public var tiltControlsEnabled: Bool
  public var leftHandedControls: Bool
  public var inputSensitivity: Double
  public var assistModeEnabled: Bool

  public init(
    musicEnabled: Bool = true,
    effectsEnabled: Bool = true,
    vibrationEnabled: Bool = true,
    captionsEnabled: Bool = true,
    reducedMotionEnabled: Bool = false,
    screenShakeEnabled: Bool = true,
    highContrastEnabled: Bool = false,
    tiltControlsEnabled: Bool = true,
    leftHandedControls: Bool = false,
    inputSensitivity: Double = 1,
    assistModeEnabled: Bool = false
  ) {
    self.musicEnabled = musicEnabled
    self.effectsEnabled = effectsEnabled
    self.vibrationEnabled = vibrationEnabled
    self.captionsEnabled = captionsEnabled
    self.reducedMotionEnabled = reducedMotionEnabled
    self.screenShakeEnabled = screenShakeEnabled
    self.highContrastEnabled = highContrastEnabled
    self.tiltControlsEnabled = tiltControlsEnabled
    self.leftHandedControls = leftHandedControls
    self.inputSensitivity = min(1.5, max(0.5, inputSensitivity))
    self.assistModeEnabled = assistModeEnabled
  }

  private enum CodingKeys: String, CodingKey {
    case musicEnabled
    case effectsEnabled
    case vibrationEnabled
    case captionsEnabled
    case reducedMotionEnabled
    case screenShakeEnabled
    case highContrastEnabled
    case tiltControlsEnabled
    case leftHandedControls
    case inputSensitivity
    case assistModeEnabled
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      musicEnabled: try values.decodeIfPresent(Bool.self, forKey: .musicEnabled) ?? true,
      effectsEnabled: try values.decodeIfPresent(Bool.self, forKey: .effectsEnabled) ?? true,
      vibrationEnabled: try values.decodeIfPresent(Bool.self, forKey: .vibrationEnabled) ?? true,
      captionsEnabled: try values.decodeIfPresent(Bool.self, forKey: .captionsEnabled) ?? true,
      reducedMotionEnabled: try values.decodeIfPresent(Bool.self, forKey: .reducedMotionEnabled)
        ?? false,
      screenShakeEnabled: try values.decodeIfPresent(Bool.self, forKey: .screenShakeEnabled)
        ?? true,
      highContrastEnabled: try values.decodeIfPresent(Bool.self, forKey: .highContrastEnabled)
        ?? false,
      tiltControlsEnabled: try values.decodeIfPresent(Bool.self, forKey: .tiltControlsEnabled)
        ?? true,
      leftHandedControls: try values.decodeIfPresent(Bool.self, forKey: .leftHandedControls)
        ?? false,
      inputSensitivity: try values.decodeIfPresent(Double.self, forKey: .inputSensitivity) ?? 1,
      assistModeEnabled: try values.decodeIfPresent(Bool.self, forKey: .assistModeEnabled) ?? false
    )
  }
}
