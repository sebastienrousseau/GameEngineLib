import Foundation

public struct LeaderboardEntry: Identifiable, Equatable, Codable, Sendable {
  public let id: UUID
  public let playerName: String
  public let score: Int
  public let achievedAt: Date

  public init(id: UUID = UUID(), playerName: String, score: Int, achievedAt: Date = Date()) {
    self.id = id
    self.playerName = playerName
    self.score = score
    self.achievedAt = achievedAt
  }
}

public struct Leaderboard: Equatable, Codable, Sendable {
  public private(set) var entries: [LeaderboardEntry]
  public let capacity: Int

  public init(entries: [LeaderboardEntry] = [], capacity: Int = 10) {
    self.capacity = max(1, capacity)
    self.entries = Array(Self.ranked(entries).prefix(max(1, capacity)))
  }

  @discardableResult public mutating func submit(_ entry: LeaderboardEntry) -> Int? {
    entries.append(entry)
    entries = Array(Self.ranked(entries).prefix(capacity))
    return entries.firstIndex(where: { $0.id == entry.id }).map { $0 + 1 }
  }

  public var bestScore: Int { entries.first?.score ?? 0 }

  private static func ranked(_ values: [LeaderboardEntry]) -> [LeaderboardEntry] {
    values.sorted {
      if $0.score != $1.score { return $0.score > $1.score }
      if $0.achievedAt != $1.achievedAt { return $0.achievedAt < $1.achievedAt }
      return $0.id.uuidString < $1.id.uuidString
    }
  }
}
