import Foundation

/// Raison pour laquelle la protection n'est pas assurée.
public enum UnavailabilityReason: Equatable, Sendable {
    case bluetoothPoweredOff
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case noDeviceSelected
    /// Aucune mesure reçue pendant la détection initiale.
    case deviceNotDetected
    /// Des mesures ont été reçues, mais jamais au-dessus du seuil de retour.
    case deviceTooFar
    /// État « ErreurVerrouillage » de la spec : le verrouillage a échoué ou n'a pas été confirmé.
    case lockFailed(String)

    var isBluetoothIssue: Bool {
        switch self {
        case .bluetoothPoweredOff, .bluetoothUnauthorized, .bluetoothUnsupported: true
        default: false
        }
    }
}

public enum DepartureCause: Equatable, Sendable {
    case weakSignal
    case noMeasurement
}

/// États de la machine à états (spec, section 5).
public enum ProximityState: Equatable, Sendable {
    /// Recherche du téléphone. Ne déclenche jamais de verrouillage.
    case initializing(since: Date)
    case unavailable(UnavailabilityReason)
    /// Téléphone proche : protection armée.
    case near
    /// Signal faible ou absent depuis `since`, en attente de confirmation.
    case departureSuspected(cause: DepartureCause, since: Date)
    case lockRequested(at: Date)
    case locked
    /// Pause manuelle ; `until == nil` signifie jusqu'à réactivation.
    case paused(until: Date?)

    /// Vrai uniquement lorsque l'application peut effectivement déclencher un verrouillage.
    public var isProtectionArmed: Bool {
        switch self {
        case .near, .departureSuspected, .lockRequested: true
        default: false
        }
    }
}

public enum BluetoothAvailability: Equatable, Sendable {
    case unknown
    case available
    case poweredOff
    case unauthorized
    case unsupported

    var unavailabilityReason: UnavailabilityReason? {
        switch self {
        case .available, .unknown: nil
        case .poweredOff: .bluetoothPoweredOff
        case .unauthorized: .bluetoothUnauthorized
        case .unsupported: .bluetoothUnsupported
        }
    }
}

/// Entrées du moteur. Toutes les dates sont fournies par l'appelant (horloge injectée).
public enum ProximityEvent: Equatable, Sendable {
    case bluetoothAvailabilityChanged(BluetoothAvailability)
    case targetDeviceChanged(isSelected: Bool)
    case measurement(rssi: Int)
    /// Évaluation périodique des temporisations.
    case tick
    case sessionLocked
    case sessionUnlocked
    case lockFailed(String)
    case systemWillSleep
    case systemDidWake
    case pause(until: Date?)
    case resume
}

/// Sorties du moteur, exécutées par l'appelant.
public enum ProximityAction: Equatable, Sendable {
    case requestLock
}
