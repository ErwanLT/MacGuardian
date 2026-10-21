import Foundation

/// Médiane glissante dans le temps : réduit l'effet des pics ponctuels du RSSI.
public struct RSSIFilter: Sendable {
    public struct Sample: Equatable, Sendable {
        public let rssi: Int
        public let date: Date
    }

    public var window: TimeInterval
    public private(set) var samples: [Sample] = []

    public init(window: TimeInterval) {
        self.window = window
    }

    public var lastSampleDate: Date? { samples.last?.date }

    public mutating func add(rssi: Int, at date: Date) {
        samples.append(Sample(rssi: rssi, date: date))
        prune(now: date)
    }

    public mutating func prune(now: Date) {
        samples.removeAll { now.timeIntervalSince($0.date) > window }
    }

    public mutating func reset() {
        samples.removeAll()
    }

    /// Médiane des mesures de la fenêtre, `nil` s'il n'y en a aucune.
    public var median: Int? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.map(\.rssi).sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            // Arrondi vers le bas (valeur la plus pessimiste) pour rester entier.
            return Int((Double(sorted[middle - 1] + sorted[middle]) / 2).rounded(.down))
        }
        return sorted[middle]
    }
}
