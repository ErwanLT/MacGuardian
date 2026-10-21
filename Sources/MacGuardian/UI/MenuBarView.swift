import MacGuardianCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: GuardianController
    @ObservedObject var bluetooth: BluetoothMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let presentation = StatePresentation(controller.state)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: presentation.symbol)
                    .font(.title2)
                    .foregroundStyle(presentation.color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title).font(.headline)
                    Text(presentation.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let name = controller.settings.targetDeviceName {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Text("Téléphone").foregroundStyle(.secondary)
                        Text(name)
                    }
                    GridRow {
                        Text("Liaison").foregroundStyle(.secondary)
                        Text(linkDescription)
                    }
                    GridRow {
                        Text("Signal filtré").foregroundStyle(.secondary)
                        Text(controller.filteredRSSI.map { "\($0) dBm" } ?? "—")
                            .monospacedDigit()
                    }
                }
                .font(.callout)
            }

            Divider()

            if case .paused = controller.state {
                Button("Reprendre la protection") { controller.resume() }
            } else {
                Menu("Mettre en pause") {
                    Button("15 minutes") { controller.pause(for: 15 * 60) }
                    Button("1 heure") { controller.pause(for: 60 * 60) }
                    Button("Jusqu'à réactivation") { controller.pause(for: nil) }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            HStack {
                Button("Réglages…") {
                    openWindow(id: SettingsView.windowID)
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quitter") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var linkDescription: String {
        switch bluetooth.targetLink {
        case .notSelected: "—"
        case .searching: "Recherche"
        case .connecting: "Connexion en attente"
        case .connected: "Connecté"
        }
    }
}
