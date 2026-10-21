import AppKit

/// Son joué sur le Mac au moment de la demande de verrouillage : l'utilisateur l'entend en s'éloignant.
@MainActor
enum LockSound {
    static let defaultName = "Glass"

    /// Sons système disponibles (/System/Library/Sounds), triés par nom.
    static var availableNames: [String] {
        let directory = URL(fileURLWithPath: "/System/Library/Sounds")
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.map { $0.deletingPathExtension().lastPathComponent }.sorted()
    }

    /// Garde une référence pendant la lecture : un `NSSound` libéré s'arrête immédiatement.
    private static var current: NSSound?

    static func play(_ name: String) {
        current?.stop()
        current = NSSound(named: NSSound.Name(name))
        current?.play()
    }
}
