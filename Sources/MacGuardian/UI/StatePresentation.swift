import MacGuardianCore
import SwiftUI

/// Libellés et icônes d'un état. Une absence de signal n'est jamais présentée comme une distance.
struct StatePresentation {
    let title: String
    let detail: String
    let symbol: String
    let color: Color

    init(_ state: ProximityState) {
        switch state {
        case .initializing:
            title = "Recherche du téléphone"
            detail = "La protection s'armera dès que le téléphone sera détecté à proximité."
            symbol = "shield.lefthalf.filled"
            color = .secondary
        case .near:
            title = "Protection active"
            detail = "Téléphone détecté à proximité."
            symbol = "lock.shield"
            color = .green
        case .departureSuspected(.weakSignal, _):
            title = "Éloignement suspecté"
            detail = "Signal faible : verrouillage si la situation se confirme."
            symbol = "exclamationmark.shield"
            color = .orange
        case .departureSuspected(.noMeasurement, _):
            title = "Téléphone non reçu"
            detail = "Aucune mesure récente : verrouillage si la situation se confirme."
            symbol = "exclamationmark.shield"
            color = .orange
        case .lockRequested:
            title = "Verrouillage demandé"
            detail = "En attente de la confirmation du système."
            symbol = "lock.badge.clock"
            color = .orange
        case .locked:
            title = "Session verrouillée"
            detail = "Verrouillage confirmé par le système."
            symbol = "lock.fill"
            color = .secondary
        case .paused(let until):
            title = "Protection en pause"
            if let until {
                detail = "Reprise automatique à \(until.formatted(date: .omitted, time: .shortened))."
            } else {
                detail = "Jusqu'à réactivation manuelle."
            }
            symbol = "pause.circle"
            color = .secondary
        case .unavailable(let reason):
            title = "Protection indisponible"
            detail = Self.describe(reason)
            symbol = "shield.slash"
            color = .red
        }
    }

    private static func describe(_ reason: UnavailabilityReason) -> String {
        switch reason {
        case .bluetoothPoweredOff: "Le Bluetooth est désactivé."
        case .bluetoothUnauthorized: "MacGuardian n'est pas autorisé à utiliser le Bluetooth (Réglages Système › Confidentialité)."
        case .bluetoothUnsupported: "Ce Mac ne prend pas en charge le Bluetooth Low Energy."
        case .noDeviceSelected: "Aucun téléphone sélectionné."
        case .deviceNotDetected: "Le téléphone n'est pas détecté."
        case .deviceTooFar: "Le téléphone est détecté, mais jamais assez proche pour armer la protection."
        case .lockFailed(let message): "Échec du verrouillage : \(message)"
        }
    }
}
