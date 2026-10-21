import Foundation
import MacGuardianCore

/// Enregistre les mesures du périphérique surveillé au format `MeasurementTrace`,
/// pour calibrer les seuils en rejouant la trace dans le moteur.
@MainActor
final class TraceRecorder {
    private(set) var fileURL: URL?
    private var handle: FileHandle?
    private var start: Date?
    private var hasMeasurementSinceLastTick = false

    var isRecording: Bool { handle != nil }

    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacGuardian/Traces", isDirectory: true)
    }

    func begin(now: Date = Date()) throws {
        stop()
        try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = Self.directory.appendingPathComponent("trace_\(formatter.string(from: now)).csv")
        try (MeasurementTrace.header + "\n").write(to: url, atomically: true, encoding: .utf8)
        handle = try FileHandle(forWritingTo: url)
        handle?.seekToEndOfFile()
        fileURL = url
        start = now
        hasMeasurementSinceLastTick = false
    }

    func stop() {
        try? handle?.close()
        handle = nil
        start = nil
    }

    func recordMeasurement(_ rssi: Int, at date: Date) {
        hasMeasurementSinceLastTick = true
        write(rssi: rssi, at: date)
    }

    /// Une ligne sans RSSI matérialise une seconde sans aucune mesure.
    func recordTick(at date: Date) {
        if !hasMeasurementSinceLastTick { write(rssi: nil, at: date) }
        hasMeasurementSinceLastTick = false
    }

    private func write(rssi: Int?, at date: Date) {
        guard let handle, let start else { return }
        let line = MeasurementTrace.csvLine(offset: date.timeIntervalSince(start), rssi: rssi) + "\n"
        handle.write(Data(line.utf8))
    }
}
