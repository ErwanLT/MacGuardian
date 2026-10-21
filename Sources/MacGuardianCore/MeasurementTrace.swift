import Foundation

/// Trace de mesures RSSI enregistrée sur le matériel réel, rejouable dans le moteur
/// pour calibrer les seuils (spec, étapes 1 et 2).
///
/// Format CSV : `secondes_depuis_debut;rssi` avec un RSSI vide pour un tick sans mesure.
public struct MeasurementTrace: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let offset: TimeInterval
        public let rssi: Int?

        public init(offset: TimeInterval, rssi: Int?) {
            self.offset = offset
            self.rssi = rssi
        }
    }

    public static let header = "offset_s;rssi"

    public var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    public init(csv: String) throws {
        var entries: [Entry] = []
        for (index, rawLine) in csv.split(whereSeparator: \.isNewline).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line == Self.header || line.hasPrefix("#") { continue }
            let fields = line.split(separator: ";", omittingEmptySubsequences: false)
            guard fields.count == 2, let offset = TimeInterval(fields[0]) else {
                throw ParseError(line: index + 1, content: line)
            }
            let rssiField = fields[1].trimmingCharacters(in: .whitespaces)
            if rssiField.isEmpty {
                entries.append(Entry(offset: offset, rssi: nil))
            } else if let rssi = Int(rssiField) {
                entries.append(Entry(offset: offset, rssi: rssi))
            } else {
                throw ParseError(line: index + 1, content: line)
            }
        }
        self.entries = entries
    }

    public struct ParseError: Error, Equatable {
        public let line: Int
        public let content: String
    }

    public static func csvLine(offset: TimeInterval, rssi: Int?) -> String {
        String(format: "%.3f;", offset) + (rssi.map(String.init) ?? "")
    }

    /// Rejoue la trace : chaque entrée envoie une mesure (si présente) puis un tick.
    /// Renvoie l'historique des changements d'état et les instants des demandes de verrouillage.
    public func replay(
        configuration: ProximityConfiguration,
        start: Date = Date(timeIntervalSinceReferenceDate: 0)
    ) -> ReplayResult {
        var engine = ProximityEngine(configuration: configuration, hasTargetDevice: true, now: start)
        engine.handle(.bluetoothAvailabilityChanged(.available), now: start)
        var result = ReplayResult(states: [(0, engine.state)], lockRequests: [])
        for entry in entries {
            let now = start.addingTimeInterval(entry.offset)
            if let rssi = entry.rssi { engine.handle(.measurement(rssi: rssi), now: now) }
            if engine.handle(.tick, now: now) == .requestLock {
                result.lockRequests.append(entry.offset)
            }
            if engine.state != result.states.last?.state {
                result.states.append((entry.offset, engine.state))
            }
        }
        return result
    }

    public struct ReplayResult: Sendable {
        public var states: [(offset: TimeInterval, state: ProximityState)]
        public var lockRequests: [TimeInterval]
    }
}
