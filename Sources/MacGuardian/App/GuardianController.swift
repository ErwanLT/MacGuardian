import Combine
import Foundation
import MacGuardianCore

/// Relie la détection Bluetooth, le moteur de proximité, le verrouillage et l'état de session.
@MainActor
final class GuardianController: ObservableObject {
    struct LockAttempt: Equatable {
        enum Outcome: Equatable {
            case pending
            case confirmed
            case failed(String)
        }

        let date: Date
        let mechanism: LockMechanismKind
        let isTest: Bool
        var outcome: Outcome
    }

    @Published private(set) var state: ProximityState
    @Published private(set) var filteredRSSI: Int?
    @Published private(set) var lastLockAttempt: LockAttempt?
    @Published private(set) var isRecordingTrace = false
    @Published private(set) var traceURL: URL?
    @Published private(set) var traceError: String?

    let settings: SettingsStore
    let bluetooth: BluetoothMonitor

    private var engine: ProximityEngine
    private let session = SessionMonitor()
    private let traceRecorder = TraceRecorder()
    private var tickTimer: Timer?
    private var testLockTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    private static let tickInterval: TimeInterval = 1

    convenience init() {
        self.init(settings: SettingsStore(), bluetooth: BluetoothMonitor())
    }

    init(settings: SettingsStore, bluetooth: BluetoothMonitor) {
        self.settings = settings
        self.bluetooth = bluetooth
        let now = Date()
        engine = ProximityEngine(
            configuration: settings.configuration,
            hasTargetDevice: settings.targetDeviceID != nil,
            now: now
        )
        state = engine.state
        start()
    }

    // MARK: - Commandes

    func pause(for duration: TimeInterval?) {
        send(.pause(until: duration.map { Date().addingTimeInterval($0) }))
    }

    func resume() {
        send(.resume)
    }

    func selectDevice(_ device: BluetoothDevice?) {
        settings.targetDeviceID = device?.id
        settings.targetDeviceName = device?.displayName
    }

    /// Verrouille après un court délai pour vérifier le mécanisme choisi, hors machine à états.
    func testLock(after delay: TimeInterval = 3) {
        testLockTimer?.invalidate()
        testLockTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.performLock(isTest: true) }
        }
    }

    func setTraceRecording(_ enabled: Bool) {
        traceError = nil
        if enabled {
            do {
                try traceRecorder.begin()
                traceURL = traceRecorder.fileURL
            } catch {
                traceError = error.localizedDescription
            }
        } else {
            traceRecorder.stop()
        }
        isRecordingTrace = traceRecorder.isRecording
    }

    // MARK: - Câblage

    private func start() {
        bluetooth.targetID = settings.targetDeviceID
        bluetooth.onAvailabilityChange = { [weak self] availability in
            self?.send(.bluetoothAvailabilityChanged(availability))
        }
        bluetooth.onTargetMeasurement = { [weak self] rssi in
            self?.traceRecorder.recordMeasurement(rssi, at: Date())
            self?.send(.measurement(rssi: rssi))
        }

        session.onLocked = { [weak self] in self?.sessionDidLock() }
        session.onUnlocked = { [weak self] in self?.send(.sessionUnlocked) }
        session.onWillSleep = { [weak self] in self?.send(.systemWillSleep) }
        session.onDidWake = { [weak self] in self?.send(.systemDidWake) }

        settings.$configuration
            .dropFirst()
            .filter(\.isValid)
            .sink { [weak self] configuration in self?.engine.configuration = configuration }
            .store(in: &cancellables)

        settings.$targetDeviceID
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] id in
                self?.bluetooth.targetID = id
                self?.send(.targetDeviceChanged(isSelected: id != nil))
            }
            .store(in: &cancellables)

        session.start()
        bluetooth.start()
        if SessionMonitor.isScreenLocked { send(.sessionLocked) }

        tickTimer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.traceRecorder.recordTick(at: Date())
                self.send(.tick)
            }
        }
    }

    private func send(_ event: ProximityEvent) {
        let action = engine.handle(event, now: Date())
        state = engine.state
        filteredRSSI = engine.filteredRSSI
        if action == .requestLock { performLock(isTest: false) }
        if case .unavailable(.lockFailed(let message)) = state, lastLockAttempt?.outcome == .pending {
            lastLockAttempt?.outcome = .failed(message)
        }
    }

    private func performLock(isTest: Bool) {
        let mechanism = settings.lockMechanism
        lastLockAttempt = LockAttempt(date: Date(), mechanism: mechanism, isTest: isTest, outcome: .pending)
        if let sound = settings.lockSoundName { LockSound.play(sound) }
        switch LockController.lock(using: mechanism) {
        case .success:
            if isTest { scheduleTestConfirmationTimeout() }
        case .failure(let error):
            let message = error.localizedDescription
            lastLockAttempt?.outcome = .failed(message)
            if !isTest { send(.lockFailed(message)) }
        }
    }

    private func scheduleTestConfirmationTimeout() {
        let timeout = settings.configuration.lockConfirmationTimeout
        testLockTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.lastLockAttempt?.outcome == .pending else { return }
                self.lastLockAttempt?.outcome = .failed("Le système n'a pas confirmé le verrouillage.")
            }
        }
    }

    private func sessionDidLock() {
        if lastLockAttempt?.outcome == .pending { lastLockAttempt?.outcome = .confirmed }
        send(.sessionLocked)
    }
}
