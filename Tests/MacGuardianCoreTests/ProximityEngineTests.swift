import Foundation
import Testing
@testable import MacGuardianCore

/// Horloge de test : les instants sont exprimés en secondes depuis t0.
private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

private func makeEngine(
    _ configuration: ProximityConfiguration = .default,
    hasTarget: Bool = true
) -> ProximityEngine {
    var engine = ProximityEngine(configuration: configuration, hasTargetDevice: hasTarget, now: t0)
    engine.handle(.bluetoothAvailabilityChanged(.available), now: t0)
    return engine
}

/// Envoie une mesure par seconde de `from` à `to` inclus, avec un tick après chacune.
@discardableResult
private func feed(
    _ engine: inout ProximityEngine,
    rssi: Int,
    from: TimeInterval,
    to: TimeInterval
) -> [ProximityAction] {
    var actions: [ProximityAction] = []
    var second = from
    while second <= to {
        engine.handle(.measurement(rssi: rssi), now: at(second))
        if let action = engine.handle(.tick, now: at(second)) { actions.append(action) }
        second += 1
    }
    return actions
}

/// Envoie uniquement des ticks (aucune mesure) de `from` à `to` inclus.
@discardableResult
private func silence(_ engine: inout ProximityEngine, from: TimeInterval, to: TimeInterval) -> [ProximityAction] {
    var actions: [ProximityAction] = []
    var second = from
    while second <= to {
        if let action = engine.handle(.tick, now: at(second)) { actions.append(action) }
        second += 1
    }
    return actions
}

private func armedEngine() -> ProximityEngine {
    var engine = makeEngine()
    feed(&engine, rssi: -55, from: 0, to: 2)
    return engine
}

@Suite("Initialisation et armement")
struct InitializationTests {
    @Test func startsInitializingWithTarget() {
        let engine = makeEngine()
        #expect(engine.state == .initializing(since: t0))
        #expect(!engine.state.isProtectionArmed)
    }

    @Test func unavailableWithoutTarget() {
        let engine = makeEngine(hasTarget: false)
        #expect(engine.state == .unavailable(.noDeviceSelected))
    }

    @Test func armsWhenPhoneSeenNear() {
        var engine = makeEngine()
        feed(&engine, rssi: -60, from: 0, to: 0)
        #expect(engine.state == .near)
        #expect(engine.state.isProtectionArmed)
    }

    @Test func weakSignalAtStartupNeverLocks() {
        var engine = makeEngine()
        let actions = feed(&engine, rssi: -85, from: 0, to: 60)
        #expect(actions.isEmpty)
        #expect(engine.state == .unavailable(.deviceTooFar))
    }

    @Test func noSignalAtStartupBecomesNotDetected() {
        var engine = makeEngine()
        let actions = silence(&engine, from: 0, to: 30)
        #expect(actions.isEmpty)
        #expect(engine.state == .unavailable(.deviceNotDetected))
    }

    @Test func rearmsFromUnavailableWhenPhoneReturns() {
        var engine = makeEngine()
        silence(&engine, from: 0, to: 30)
        feed(&engine, rssi: -60, from: 31, to: 31)
        #expect(engine.state == .near)
    }

    @Test func hysteresisBandDoesNotArm() {
        var engine = makeEngine()
        feed(&engine, rssi: -70, from: 0, to: 10)
        #expect(engine.state == .initializing(since: t0))
    }
}

@Suite("Éloignement et retour")
struct DepartureTests {
    @Test func singleSpikeDoesNotTriggerDeparture() {
        var engine = armedEngine()
        feed(&engine, rssi: -55, from: 3, to: 4)
        feed(&engine, rssi: -95, from: 5, to: 5)
        feed(&engine, rssi: -55, from: 6, to: 7)
        #expect(engine.state == .near)
    }

    @Test func sustainedWeakSignalLocksOnceAfterDelay() {
        var engine = armedEngine()
        let actions = feed(&engine, rssi: -85, from: 3, to: 60)
        #expect(actions == [.requestLock])
        // Aucun `sessionLocked` envoyé : la demande n'est pas confirmée et devient une erreur.
        if case .unavailable(.lockFailed) = engine.state {} else {
            Issue.record("État inattendu : \(engine.state)")
        }
    }

    @Test func weakSignalLockHappensAfterConfiguredDelay() {
        var engine = armedEngine()
        // La médiane passe sous -75 à la 2e mesure faible sur 5 s de fenêtre (3 fortes + 2 faibles → non),
        // on mesure donc l'instant exact plutôt qu'une valeur codée en dur.
        var departureStart: TimeInterval?
        var lockAt: TimeInterval?
        for second in stride(from: 3.0, through: 60, by: 1) {
            engine.handle(.measurement(rssi: -85), now: at(second))
            if departureStart == nil, case .departureSuspected = engine.state { departureStart = second }
            if engine.handle(.tick, now: at(second)) == .requestLock { lockAt = second; break }
        }
        let start = try! #require(departureStart)
        #expect(lockAt == start + ProximityConfiguration.default.weakSignalDelay)
    }

    @Test func returnAboveThresholdCancelsDeparture() {
        var engine = armedEngine()
        feed(&engine, rssi: -85, from: 3, to: 10)
        if case .departureSuspected(.weakSignal, _) = engine.state {} else {
            Issue.record("Éloignement attendu : \(engine.state)")
        }
        let actions = feed(&engine, rssi: -55, from: 11, to: 30)
        #expect(actions.isEmpty)
        #expect(engine.state == .near)
    }

    @Test func hysteresisBandKeepsNear() {
        var engine = armedEngine()
        let actions = feed(&engine, rssi: -70, from: 3, to: 60)
        #expect(actions.isEmpty)
        #expect(engine.state == .near)
    }

    @Test func hysteresisBandDoesNotCancelDeparture() {
        var engine = armedEngine()
        feed(&engine, rssi: -85, from: 3, to: 9)
        let actions = feed(&engine, rssi: -70, from: 10, to: 40)
        #expect(actions == [.requestLock])
    }

    @Test func missingMeasurementsLockAfterNoMeasurementDelay() {
        var engine = armedEngine() // dernière mesure à t=2
        var lockAt: TimeInterval?
        for second in stride(from: 3.0, through: 60, by: 1) {
            if engine.handle(.tick, now: at(second)) == .requestLock { lockAt = second; break }
        }
        #expect(lockAt == 2 + ProximityConfiguration.default.noMeasurementDelay)
    }

    @Test func shortGapIsTolerated() {
        var engine = armedEngine()
        silence(&engine, from: 3, to: 7) // 5 s sans mesure = tolérance
        #expect(engine.state == .near)
    }

    @Test func measurementsReturningNearCancelNoMeasurementEpisode() {
        var engine = armedEngine()
        silence(&engine, from: 3, to: 12)
        if case .departureSuspected(.noMeasurement, _) = engine.state {} else {
            Issue.record("Absence de mesures attendue : \(engine.state)")
        }
        feed(&engine, rssi: -55, from: 13, to: 13)
        #expect(engine.state == .near)
    }

    @Test func weakMeasurementsKeepEpisodeStart() {
        var engine = armedEngine()
        silence(&engine, from: 3, to: 10)
        feed(&engine, rssi: -85, from: 11, to: 11)
        #expect(engine.state == .departureSuspected(cause: .weakSignal, since: at(2)))
    }
}

@Suite("Verrouillage")
struct LockTests {
    private func lockRequestedEngine() -> ProximityEngine {
        var engine = armedEngine()
        silence(&engine, from: 3, to: 22)
        return engine
    }

    @Test func sessionLockedConfirmsLock() {
        var engine = lockRequestedEngine()
        engine.handle(.sessionLocked, now: at(23))
        #expect(engine.state == .locked)
    }

    @Test func missingConfirmationIsAnError() {
        var engine = lockRequestedEngine()
        silence(&engine, from: 23, to: 26)
        if case .unavailable(.lockFailed) = engine.state {} else {
            Issue.record("Erreur de verrouillage attendue : \(engine.state)")
        }
        #expect(!engine.state.isProtectionArmed)
    }

    @Test func reportedFailureIsAnError() {
        var engine = lockRequestedEngine()
        engine.handle(.lockFailed("boom"), now: at(23))
        #expect(engine.state == .unavailable(.lockFailed("boom")))
    }

    @Test func onlyOneLockRequestPerEpisode() {
        var engine = armedEngine()
        let actions = silence(&engine, from: 3, to: 300)
        #expect(actions == [.requestLock])
    }

    @Test func unlockWithPhoneAwayDoesNotRelock() {
        var engine = lockRequestedEngine()
        engine.handle(.sessionLocked, now: at(23))
        engine.handle(.sessionUnlocked, now: at(100))
        let actions = feed(&engine, rssi: -90, from: 100, to: 400)
        #expect(actions.isEmpty)
        #expect(engine.state == .unavailable(.deviceTooFar))
    }

    @Test func unlockThenPhoneNearRearms() {
        var engine = lockRequestedEngine()
        engine.handle(.sessionLocked, now: at(23))
        engine.handle(.sessionUnlocked, now: at(100))
        feed(&engine, rssi: -55, from: 100, to: 101)
        #expect(engine.state == .near)
    }

    @Test func manualLockWhileNearGoesLocked() {
        var engine = armedEngine()
        engine.handle(.sessionLocked, now: at(5))
        #expect(engine.state == .locked)
        let actions = silence(&engine, from: 6, to: 100)
        #expect(actions.isEmpty)
    }
}

@Suite("Bluetooth, veille et pause")
struct LifecycleTests {
    @Test func bluetoothOffMakesProtectionUnavailable() {
        var engine = armedEngine()
        engine.handle(.bluetoothAvailabilityChanged(.poweredOff), now: at(5))
        #expect(engine.state == .unavailable(.bluetoothPoweredOff))
        let actions = silence(&engine, from: 6, to: 100)
        #expect(actions.isEmpty)
    }

    @Test func bluetoothBackOnReinitializes() {
        var engine = armedEngine()
        engine.handle(.bluetoothAvailabilityChanged(.poweredOff), now: at(5))
        engine.handle(.bluetoothAvailabilityChanged(.available), now: at(10))
        #expect(engine.state == .initializing(since: at(10)))
    }

    @Test func unauthorizedIsReported() {
        var engine = makeEngine()
        engine.handle(.bluetoothAvailabilityChanged(.unauthorized), now: at(1))
        #expect(engine.state == .unavailable(.bluetoothUnauthorized))
    }

    @Test func wakeReinitializesInsteadOfLocking() {
        var engine = armedEngine()
        engine.handle(.systemWillSleep, now: at(3))
        // Tick tardif reçu au réveil avant la notification : ne doit pas verrouiller.
        let action = engine.handle(.tick, now: at(3_600))
        engine.handle(.systemDidWake, now: at(3_600))
        #expect(action == nil)
        #expect(engine.state == .initializing(since: at(3_600)))
    }

    @Test func pauseSuspendsProtection() {
        var engine = armedEngine()
        engine.handle(.pause(until: nil), now: at(3))
        let actions = silence(&engine, from: 4, to: 300)
        #expect(actions.isEmpty)
        #expect(engine.state == .paused(until: nil))
    }

    @Test func timedPauseEndsAutomatically() {
        var engine = armedEngine()
        engine.handle(.pause(until: at(60)), now: at(3))
        silence(&engine, from: 4, to: 60)
        #expect(engine.state == .initializing(since: at(60)))
    }

    @Test func resumeReinitializes() {
        var engine = armedEngine()
        engine.handle(.pause(until: nil), now: at(3))
        engine.handle(.resume, now: at(10))
        #expect(engine.state == .initializing(since: at(10)))
    }

    @Test func targetChangeReinitializes() {
        var engine = armedEngine()
        engine.handle(.targetDeviceChanged(isSelected: false), now: at(5))
        #expect(engine.state == .unavailable(.noDeviceSelected))
        engine.handle(.targetDeviceChanged(isSelected: true), now: at(6))
        #expect(engine.state == .initializing(since: at(6)))
    }
}

@Suite("Filtre et traces")
struct FilterAndTraceTests {
    @Test func medianIgnoresOutliers() {
        var filter = RSSIFilter(window: 5)
        for (offset, rssi) in [-60, -61, -100, -59, -60].enumerated() {
            filter.add(rssi: rssi, at: at(Double(offset)))
        }
        #expect(filter.median == -60)
    }

    @Test func filterDropsOldSamples() {
        var filter = RSSIFilter(window: 5)
        filter.add(rssi: -90, at: at(0))
        filter.add(rssi: -60, at: at(10))
        #expect(filter.median == -60)
        filter.prune(now: at(20))
        #expect(filter.median == nil)
    }

    @Test func configurationRequiresHysteresis() {
        #expect(ProximityConfiguration.default.isValid)
        #expect(!ProximityConfiguration(departureThreshold: -70, returnThreshold: -70).isValid)
    }

    @Test func traceRoundTripAndReplay() throws {
        var lines = [MeasurementTrace.header]
        for second in 0..<5 { lines.append(MeasurementTrace.csvLine(offset: Double(second), rssi: -55)) }
        for second in 5..<40 { lines.append(MeasurementTrace.csvLine(offset: Double(second), rssi: nil)) }
        let trace = try MeasurementTrace(csv: lines.joined(separator: "\n"))
        #expect(trace.entries.count == 40)
        #expect(trace.entries[5].rssi == nil)

        let result = trace.replay(configuration: .default)
        #expect(result.lockRequests == [24]) // dernière mesure à 4 s + 20 s
        #expect(result.states.contains { $0.state == .near })
    }

    @Test func malformedTraceIsRejected() {
        #expect(throws: MeasurementTrace.ParseError.self) {
            try MeasurementTrace(csv: "offset_s;rssi\n1.0;abc")
        }
    }
}
