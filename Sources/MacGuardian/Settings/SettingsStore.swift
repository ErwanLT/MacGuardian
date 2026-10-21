import Foundation
import MacGuardianCore

/// Préférences persistées dans `UserDefaults`.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var configuration: ProximityConfiguration {
        didSet { save(configuration, for: Keys.configuration) }
    }
    @Published var targetDeviceID: UUID? {
        didSet { defaults.set(targetDeviceID?.uuidString, forKey: Keys.targetDeviceID) }
    }
    @Published var targetDeviceName: String? {
        didSet { defaults.set(targetDeviceName, forKey: Keys.targetDeviceName) }
    }
    @Published var lockMechanism: LockMechanismKind {
        didSet { defaults.set(lockMechanism.rawValue, forKey: Keys.lockMechanism) }
    }
    /// Son joué à la demande de verrouillage, `nil` pour aucun son.
    @Published var lockSoundName: String? {
        didSet { defaults.set(lockSoundName ?? "", forKey: Keys.lockSoundName) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let configuration = "proximityConfiguration"
        static let targetDeviceID = "targetDeviceID"
        static let targetDeviceName = "targetDeviceName"
        static let lockMechanism = "lockMechanism"
        static let lockSoundName = "lockSoundName"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        configuration = defaults.data(forKey: Keys.configuration)
            .flatMap { try? JSONDecoder().decode(ProximityConfiguration.self, from: $0) }
            ?? .default
        targetDeviceID = defaults.string(forKey: Keys.targetDeviceID).flatMap(UUID.init(uuidString:))
        targetDeviceName = defaults.string(forKey: Keys.targetDeviceName)
        lockMechanism = defaults.string(forKey: Keys.lockMechanism).flatMap(LockMechanismKind.init(rawValue:))
            ?? .privateLoginFramework
        // Chaîne vide enregistrée = son désactivé par l'utilisateur.
        let storedSound = defaults.string(forKey: Keys.lockSoundName) ?? LockSound.defaultName
        lockSoundName = storedSound.isEmpty ? nil : storedSound
    }

    private func save<T: Encodable>(_ value: T, for key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
