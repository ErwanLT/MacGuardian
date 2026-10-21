import Foundation

/// Seuils et temporisations du moteur de proximité (spec, section 6).
/// Les valeurs par défaut sont des points de départ à calibrer sur traces réelles.
public struct ProximityConfiguration: Equatable, Codable, Sendable {
    /// En dessous de ce RSSI filtré, le téléphone est considéré comme en train de s'éloigner.
    public var departureThreshold: Int
    /// Au-dessus de ce RSSI filtré, le téléphone est considéré comme proche (arme la protection).
    public var returnThreshold: Int
    /// Durée pendant laquelle le signal doit rester faible avant de demander le verrouillage.
    public var weakSignalDelay: TimeInterval
    /// Durée sans aucune mesure avant de demander le verrouillage.
    public var noMeasurementDelay: TimeInterval
    /// Silence toléré entre deux mesures avant de considérer qu'elles sont absentes.
    public var measurementGapTolerance: TimeInterval
    /// Fenêtre glissante sur laquelle la médiane du RSSI est calculée.
    public var medianWindow: TimeInterval
    /// Délai pour voir le téléphone à proximité au démarrage, sinon protection indisponible.
    public var initialDetectionTimeout: TimeInterval
    /// Délai pour recevoir la confirmation système du verrouillage.
    public var lockConfirmationTimeout: TimeInterval

    public init(
        departureThreshold: Int = -75,
        returnThreshold: Int = -65,
        weakSignalDelay: TimeInterval = 15,
        noMeasurementDelay: TimeInterval = 20,
        measurementGapTolerance: TimeInterval = 5,
        medianWindow: TimeInterval = 5,
        initialDetectionTimeout: TimeInterval = 30,
        lockConfirmationTimeout: TimeInterval = 3
    ) {
        self.departureThreshold = departureThreshold
        self.returnThreshold = returnThreshold
        self.weakSignalDelay = weakSignalDelay
        self.noMeasurementDelay = noMeasurementDelay
        self.measurementGapTolerance = measurementGapTolerance
        self.medianWindow = medianWindow
        self.initialDetectionTimeout = initialDetectionTimeout
        self.lockConfirmationTimeout = lockConfirmationTimeout
    }

    public static let `default` = ProximityConfiguration()

    /// Le seuil de retour doit être strictement au-dessus du seuil d'éloignement (hystérésis).
    public var isValid: Bool {
        returnThreshold > departureThreshold
            && weakSignalDelay > 0
            && noMeasurementDelay > 0
            && measurementGapTolerance > 0
            && medianWindow > 0
            && initialDetectionTimeout > 0
            && lockConfirmationTimeout > 0
    }
}
