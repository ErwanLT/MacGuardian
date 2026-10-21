import SwiftUI

@main
struct MacGuardianApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = GuardianController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller, bluetooth: controller.bluetooth)
        } label: {
            Image(systemName: StatePresentation(controller.state).symbol)
        }
        .menuBarExtraStyle(.window)

        Window("Réglages MacGuardian", id: SettingsView.windowID) {
            SettingsView(controller: controller, settings: controller.settings, bluetooth: controller.bluetooth)
        }
        .windowResizability(.contentSize)
    }
}
