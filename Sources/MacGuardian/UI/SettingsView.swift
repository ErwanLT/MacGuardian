import AppKit
import MacGuardianCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"

    @ObservedObject var controller: GuardianController
    @ObservedObject var settings: SettingsStore
    @ObservedObject var bluetooth: BluetoothMonitor

    var body: some View {
        TabView {
            DeviceTab(controller: controller, settings: settings, bluetooth: bluetooth)
                .tabItem { Label("Téléphone", systemImage: "iphone") }
            ProximityTab(settings: settings)
                .tabItem { Label("Proximité", systemImage: "dot.radiowaves.left.and.right") }
            LockTab(controller: controller, settings: settings)
                .tabItem { Label("Verrouillage", systemImage: "lock") }
            DiagnosticTab(controller: controller, bluetooth: bluetooth)
                .tabItem { Label("Diagnostic", systemImage: "waveform.path.ecg") }
        }
        .padding()
        .frame(width: 640, height: 460)
    }
}

// MARK: - Téléphone

private struct DeviceTab: View {
    @ObservedObject var controller: GuardianController
    @ObservedObject var settings: SettingsStore
    @ObservedObject var bluetooth: BluetoothMonitor
    @AppStorage("deviceList.appleOnly") private var appleOnly = true

    private var sortedDevices: [BluetoothDevice] {
        bluetooth.devices.values
            .filter { !appleOnly || $0.isApple || $0.id == settings.targetDeviceID }
            .sorted { $0.rssi > $1.rssi }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rapprochez votre iPhone du Mac : il devrait apparaître en tête de liste, avec le signal le plus fort. "
                + "L'identifiant d'un iPhone peut changer ; si le suivi se perd, sélectionnez-le à nouveau.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Toggle("Appareils Apple uniquement", isOn: $appleOnly)
                Spacer()
                if settings.targetDeviceID != nil {
                    Button("Oublier le téléphone") { controller.selectDevice(nil) }
                }
            }

            Table(sortedDevices) {
                TableColumn("") { device in
                    if device.id == settings.targetDeviceID {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .width(20)
                TableColumn("Appareil") { device in
                    VStack(alignment: .leading) {
                        Text(device.displayName)
                        Text(device.id.uuidString.prefix(8) + "…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TableColumn("RSSI") { device in
                    Text("\(device.rssi) dBm").monospacedDigit()
                }
                .width(70)
                TableColumn("Connectable") { device in
                    Text(device.isConnectable ? "Oui" : "Non")
                }
                .width(80)
                TableColumn("") { device in
                    Button("Choisir") { controller.selectDevice(device) }
                        .disabled(device.id == settings.targetDeviceID)
                }
                .width(70)
            }
        }
    }
}

// MARK: - Proximité

private struct ProximityTab: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Stepper(value: $settings.configuration.departureThreshold, in: -100 ... -30) {
                    LabeledContent("Seuil d'éloignement", value: "\(settings.configuration.departureThreshold) dBm")
                }
                Stepper(value: $settings.configuration.returnThreshold, in: -100 ... -30) {
                    LabeledContent("Seuil de retour à proximité", value: "\(settings.configuration.returnThreshold) dBm")
                }
            } footer: {
                if !settings.configuration.isValid {
                    Text("Le seuil de retour doit être supérieur au seuil d'éloignement. Réglages non appliqués.")
                        .foregroundStyle(.red)
                } else {
                    Text("Valeurs expérimentales : le RSSI ne correspond pas à une distance exacte.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                secondsStepper("Délai (signal faible)", value: $settings.configuration.weakSignalDelay, range: 3 ... 120)
                secondsStepper("Délai (aucune mesure)", value: $settings.configuration.noMeasurementDelay, range: 3 ... 120)
                secondsStepper("Fenêtre de la médiane", value: $settings.configuration.medianWindow, range: 1 ... 30)
                secondsStepper("Détection initiale", value: $settings.configuration.initialDetectionTimeout, range: 5 ... 300)
            }
            Section {
                Button("Rétablir les valeurs par défaut") { settings.configuration = .default }
            }
        }
        .formStyle(.grouped)
    }

    private func secondsStepper(_ title: String, value: Binding<TimeInterval>, range: ClosedRange<TimeInterval>) -> some View {
        Stepper(value: value, in: range, step: 1) {
            LabeledContent(title, value: "\(Int(value.wrappedValue)) s")
        }
    }
}

// MARK: - Verrouillage

private struct LockTab: View {
    @ObservedObject var controller: GuardianController
    @ObservedObject var settings: SettingsStore
    @StateObject private var model = LockTabModel()

    var body: some View {
        Form {
            Section("Mécanisme") {
                Picker("Mécanisme", selection: $settings.lockMechanism) {
                    ForEach(LockMechanismKind.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
                Text(settings.lockMechanism.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if settings.lockMechanism == .keyboardShortcut, !model.accessibilityGranted {
                    Button("Demander l'autorisation Accessibilité") {
                        LockController.requestAccessibility()
                    }
                }
            }
            Section {
                Picker("Son au verrouillage", selection: $settings.lockSoundName) {
                    Text("Aucun").tag(String?.none)
                    Divider()
                    ForEach(LockSound.availableNames, id: \.self) { Text($0).tag(String?.some($0)) }
                }
                .onChange(of: settings.lockSoundName) { name in
                    if let name { LockSound.play(name) }
                }
            } header: {
                Text("Son")
            } footer: {
                Text("Joué sur le Mac au moment du verrouillage, pour l'entendre en s'éloignant. Inaudible si le son du Mac est coupé.")
                    .foregroundStyle(.secondary)
            }
            Section("Test") {
                Button("Tester le verrouillage dans 3 secondes") { controller.testLock() }
                if let attempt = controller.lastLockAttempt {
                    LabeledContent("Dernière tentative") {
                        Text(describe(attempt)).foregroundStyle(color(attempt.outcome))
                    }
                }
            }
            Section("Démarrage") {
                Toggle("Lancer MacGuardian à l'ouverture de session", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if let launchAtLoginError = model.launchAtLoginError {
                    Text(launchAtLoginError).font(.callout).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refresh() }
    }

    private func describe(_ attempt: GuardianController.LockAttempt) -> String {
        let time = attempt.date.formatted(date: .omitted, time: .standard)
        let kind = attempt.isTest ? "test" : "automatique"
        switch attempt.outcome {
        case .pending: return "\(time) (\(kind)) : en attente de confirmation"
        case .confirmed: return "\(time) (\(kind)) : verrouillage confirmé"
        case .failed(let message): return "\(time) (\(kind)) : \(message)"
        }
    }

    private func color(_ outcome: GuardianController.LockAttempt.Outcome) -> Color {
        switch outcome {
        case .pending: .orange
        case .confirmed: .green
        case .failed: .red
        }
    }
}

@MainActor
private final class LockTabModel: ObservableObject {
    @Published private(set) var accessibilityGranted = LockController.isAccessibilityGranted
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var launchAtLoginError: String?

    func refresh() {
        accessibilityGranted = LockController.isAccessibilityGranted
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = "Impossible de modifier le lancement automatique : \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Diagnostic

private struct DiagnosticTab: View {
    @ObservedObject var controller: GuardianController
    @ObservedObject var bluetooth: BluetoothMonitor

    var body: some View {
        Form {
            Section("État") {
                LabeledContent("Machine à états", value: String(describing: controller.state))
                LabeledContent("Bluetooth", value: String(describing: bluetooth.availability))
                LabeledContent("Dernière mesure", value: bluetooth.lastTargetRSSI.map { "\($0) dBm" } ?? "—")
                LabeledContent("RSSI filtré", value: controller.filteredRSSI.map { "\($0) dBm" } ?? "—")
                LabeledContent("Appareils visibles", value: "\(bluetooth.devices.count)")
            }
            Section {
                Toggle("Enregistrer une trace des mesures", isOn: Binding(
                    get: { controller.isRecordingTrace },
                    set: { controller.setTraceRecording($0) }
                ))
                if let url = controller.traceURL {
                    LabeledContent("Fichier", value: url.lastPathComponent)
                }
                if let error = controller.traceError {
                    Text(error).foregroundStyle(.red)
                }
                Button("Afficher les traces dans le Finder") {
                    try? FileManager.default.createDirectory(at: TraceRecorder.directory, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(TraceRecorder.directory)
                }
            } header: {
                Text("Traces")
            } footer: {
                Text("Une trace se rejoue dans le moteur (MeasurementTrace.replay) pour calibrer les seuils.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
