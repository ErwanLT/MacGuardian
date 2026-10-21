import Foundation

/// Machine à états de proximité (spec, section 5).
///
/// Logique pure : aucune dépendance à Core Bluetooth, l'heure courante est passée à chaque appel.
/// Règles principales :
/// - la protection n'est armée qu'après avoir vu le téléphone au-dessus du seuil de retour ;
/// - `initializing` ne déclenche jamais de verrouillage (pas de boucle après un déverrouillage) ;
/// - une seule demande de verrouillage par épisode d'absence ;
/// - veille et réveil ramènent en `initializing`.
public struct ProximityEngine: Sendable {
    public private(set) var state: ProximityState
    public var configuration: ProximityConfiguration {
        didSet { filter.window = configuration.medianWindow }
    }

    private var filter: RSSIFilter
    private var bluetooth: BluetoothAvailability = .unknown
    private var hasTargetDevice: Bool
    private var lastMeasurementDate: Date?
    private var hasReceivedMeasurementSinceInit = false

    public init(configuration: ProximityConfiguration = .default, hasTargetDevice: Bool, now: Date) {
        self.configuration = configuration
        self.filter = RSSIFilter(window: configuration.medianWindow)
        self.hasTargetDevice = hasTargetDevice
        self.state = .initializing(since: now)
        enterInitializing(now: now)
    }

    /// RSSI filtré (médiane de la fenêtre), `nil` sans mesure récente.
    public var filteredRSSI: Int? { filter.median }

    @discardableResult
    public mutating func handle(_ event: ProximityEvent, now: Date) -> ProximityAction? {
        switch event {
        case .bluetoothAvailabilityChanged(let availability):
            bluetooth = availability
            guard !isPausedOrLocked else { return nil }
            if let reason = availability.unavailabilityReason {
                state = .unavailable(reason)
            } else if case .unavailable(let reason) = state, reason.isBluetoothIssue {
                enterInitializing(now: now)
            }

        case .targetDeviceChanged(let isSelected):
            hasTargetDevice = isSelected
            guard !isPausedOrLocked else { return nil }
            enterInitializing(now: now)

        case .measurement(let rssi):
            handleMeasurement(rssi, now: now)

        case .tick:
            return handleTick(now: now)

        case .sessionLocked:
            if case .paused = state { return nil }
            state = .locked

        case .sessionUnlocked:
            if case .locked = state { enterInitializing(now: now) }

        case .lockFailed(let message):
            if case .lockRequested = state { state = .unavailable(.lockFailed(message)) }

        case .systemWillSleep, .systemDidWake:
            guard !isPausedOrLocked else { return nil }
            enterInitializing(now: now)

        case .pause(let until):
            state = .paused(until: until)

        case .resume:
            if case .paused = state { enterInitializing(now: now) }
        }
        return nil
    }

    // MARK: - Transitions

    private var isPausedOrLocked: Bool {
        switch state {
        case .paused, .locked: true
        default: false
        }
    }

    private mutating func enterInitializing(now: Date) {
        filter.reset()
        lastMeasurementDate = nil
        hasReceivedMeasurementSinceInit = false
        if !hasTargetDevice {
            state = .unavailable(.noDeviceSelected)
        } else if let reason = bluetooth.unavailabilityReason {
            state = .unavailable(reason)
        } else {
            state = .initializing(since: now)
        }
    }

    private mutating func handleMeasurement(_ rssi: Int, now: Date) {
        filter.add(rssi: rssi, at: now)
        lastMeasurementDate = now
        guard let median = filter.median else { return }
        let isNear = median >= configuration.returnThreshold

        switch state {
        case .initializing:
            hasReceivedMeasurementSinceInit = true
            if isNear { state = .near }

        case .unavailable(let reason):
            // Indisponibilité liée au téléphone ou à un échec de verrouillage :
            // le revoir à proximité réarme la protection.
            if !reason.isBluetoothIssue, reason != .noDeviceSelected, isNear {
                state = .near
            }

        case .near:
            if median < configuration.departureThreshold {
                state = .departureSuspected(cause: .weakSignal, since: now)
            }

        case .departureSuspected(let cause, let since):
            if isNear {
                state = .near
            } else if cause == .noMeasurement {
                // Des mesures reviennent mais restent insuffisantes : l'épisode continue.
                state = .departureSuspected(cause: .weakSignal, since: since)
            }

        case .lockRequested, .locked, .paused:
            break
        }
    }

    private mutating func handleTick(now: Date) -> ProximityAction? {
        filter.prune(now: now)

        switch state {
        case .initializing(let since):
            if now.timeIntervalSince(since) >= configuration.initialDetectionTimeout {
                state = .unavailable(hasReceivedMeasurementSinceInit ? .deviceTooFar : .deviceNotDetected)
            }

        case .near:
            let last = lastMeasurementDate ?? now
            if now.timeIntervalSince(last) > configuration.measurementGapTolerance {
                state = .departureSuspected(cause: .noMeasurement, since: last)
            }

        case .departureSuspected(let cause, let since):
            let delay = cause == .weakSignal ? configuration.weakSignalDelay : configuration.noMeasurementDelay
            if now.timeIntervalSince(since) >= delay {
                state = .lockRequested(at: now)
                return .requestLock
            }

        case .lockRequested(let at):
            if now.timeIntervalSince(at) >= configuration.lockConfirmationTimeout {
                state = .unavailable(.lockFailed("Le système n'a pas confirmé le verrouillage."))
            }

        case .paused(let until):
            if let until, now >= until { enterInitializing(now: now) }

        case .unavailable, .locked:
            break
        }
        return nil
    }
}
