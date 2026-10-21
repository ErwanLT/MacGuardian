import AppKit
import CoreGraphics
import Foundation

/// Observe le verrouillage, le déverrouillage, la veille et le réveil de la session.
@MainActor
final class SessionMonitor {
    var onLocked: (() -> Void)?
    var onUnlocked: (() -> Void)?
    var onWillSleep: (() -> Void)?
    var onDidWake: (() -> Void)?

    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    func start() {
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, "com.apple.screenIsLocked") { $0.onLocked?() }
        observe(distributed, "com.apple.screenIsUnlocked") { $0.onUnlocked?() }

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification.rawValue) { $0.onWillSleep?() }
        observe(workspace, NSWorkspace.didWakeNotification.rawValue) { $0.onDidWake?() }
    }

    /// État courant lu via une clé non documentée de `CGSessionCopyCurrentDictionary`.
    /// À utiliser en complément des notifications, pas comme unique source.
    static var isScreenLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    private func observe(_ center: NotificationCenter, _ name: String, handler: @escaping (SessionMonitor) -> Void) {
        let token = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
        observers.append((center, token))
    }
}
