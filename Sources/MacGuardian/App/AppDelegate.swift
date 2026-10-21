import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Application de barre de menus : pas d'icône dans le Dock, même lancée hors bundle.
        NSApp.setActivationPolicy(.accessory)
    }
}
