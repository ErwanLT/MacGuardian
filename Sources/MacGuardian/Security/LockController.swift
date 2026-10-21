import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

/// Mécanismes de verrouillage candidats (spec, section 7).
enum LockMechanismKind: String, CaseIterable, Identifiable, Codable {
    case privateLoginFramework
    case keyboardShortcut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privateLoginFramework: "Verrouillage immédiat (API privée)"
        case .keyboardShortcut: "Raccourci ⌃⌘Q (Accessibilité)"
        }
    }

    var detail: String {
        switch self {
        case .privateLoginFramework:
            "SACLockScreenImmediate (login.framework). Aucune autorisation, mais API non publique : peut casser lors d'une mise à jour de macOS."
        case .keyboardShortcut:
            "Simule le raccourci système de verrouillage. Nécessite l'autorisation Accessibilité."
        }
    }
}

enum LockError: LocalizedError, Equatable {
    case symbolUnavailable
    case callFailed(Int32)
    case accessibilityNotGranted
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .symbolUnavailable:
            "SACLockScreenImmediate est introuvable sur cette version de macOS."
        case .callFailed(let code):
            "SACLockScreenImmediate a renvoyé l'erreur \(code)."
        case .accessibilityNotGranted:
            "MacGuardian n'a pas l'autorisation Accessibilité nécessaire au raccourci clavier."
        case .eventCreationFailed:
            "Impossible de créer les événements clavier."
        }
    }
}

/// Encapsule le mécanisme de verrouillage pour pouvoir le remplacer sans toucher à la détection.
///
/// `lock(using:)` ne fait que *demander* le verrouillage : l'effectivité est confirmée par
/// `SessionMonitor` (notification `com.apple.screenIsLocked`), jamais supposée.
enum LockController {
    static func lock(using mechanism: LockMechanismKind) -> Result<Void, LockError> {
        switch mechanism {
        case .privateLoginFramework: lockWithLoginFramework()
        case .keyboardShortcut: lockWithKeyboardShortcut()
        }
    }

    static var isAccessibilityGranted: Bool { AXIsProcessTrusted() }

    /// Ouvre la demande système d'autorisation Accessibilité.
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Mécanismes

    private typealias LockFunction = @convention(c) () -> Int32

    private static func lockWithLoginFramework() -> Result<Void, LockError> {
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate") else {
            return .failure(.symbolUnavailable)
        }
        let function = unsafeBitCast(symbol, to: LockFunction.self)
        let code = function()
        return code == 0 ? .success(()) : .failure(.callFailed(code))
    }

    private static func lockWithKeyboardShortcut() -> Result<Void, LockError> {
        guard isAccessibilityGranted else { return .failure(.accessibilityNotGranted) }
        let qKey: CGKeyCode = 12
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: qKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: qKey, keyDown: false) else {
            return .failure(.eventCreationFailed)
        }
        down.flags = [.maskCommand, .maskControl]
        up.flags = [.maskCommand, .maskControl]
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return .success(())
    }
}
