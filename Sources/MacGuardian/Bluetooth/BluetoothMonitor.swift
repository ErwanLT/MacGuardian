@preconcurrency import CoreBluetooth
import Foundation
import MacGuardianCore

/// Découverte BLE et collecte du RSSI du périphérique surveillé.
///
/// Deux sources de mesures pour le périphérique choisi :
/// - les annonces BLE reçues pendant le scan (`allowDuplicates` pour un flux continu) ;
/// - une connexion GATT maintenue, avec lecture périodique du RSSI. Une connexion établie
///   n'est pas affectée par le changement d'adresse du téléphone, contrairement au scan.
@MainActor
final class BluetoothMonitor: NSObject, ObservableObject {
    enum TargetLink: Equatable {
        case notSelected
        case searching
        case connecting
        case connected
    }

    @Published private(set) var availability: BluetoothAvailability = .unknown
    @Published private(set) var devices: [UUID: BluetoothDevice] = [:]
    @Published private(set) var targetLink: TargetLink = .notSelected
    @Published private(set) var lastTargetRSSI: Int?

    var onAvailabilityChange: ((BluetoothAvailability) -> Void)?
    var onTargetMeasurement: ((Int) -> Void)?

    var targetID: UUID? {
        didSet {
            guard targetID != oldValue else { return }
            disconnectTarget()
            lastTargetRSSI = nil
            connectTargetIfPossible()
        }
    }

    private var central: CBCentralManager?
    private var targetPeripheral: CBPeripheral?
    private var rssiTimer: Timer?
    private var pruneTimer: Timer?

    private static let rssiReadInterval: TimeInterval = 1
    private static let deviceRetention: TimeInterval = 60
    /// Valeur renvoyée par Core Bluetooth quand le RSSI n'est pas disponible.
    private static let unavailableRSSI = 127

    func start() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: nil)
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pruneDevices() }
        }
    }

    // MARK: - Scan et connexion

    private func startScanning() {
        central?.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private func connectTargetIfPossible() {
        guard let central, central.state == .poweredOn else { return }
        guard let targetID else {
            targetLink = .notSelected
            return
        }
        if targetPeripheral == nil {
            targetPeripheral = central.retrievePeripherals(withIdentifiers: [targetID]).first
        }
        guard let peripheral = targetPeripheral else {
            // Inconnu du système pour l'instant : on attend de le voir dans le scan.
            targetLink = .searching
            return
        }
        peripheral.delegate = self
        if peripheral.state == .connected {
            didConnectTarget(peripheral)
        } else {
            targetLink = .connecting
            // Une demande de connexion n'expire pas : elle aboutit dès que le téléphone est à portée.
            central.connect(peripheral, options: nil)
        }
    }

    private func disconnectTarget() {
        stopRSSITimer()
        if let peripheral = targetPeripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        targetPeripheral = nil
        targetLink = targetID == nil ? .notSelected : .searching
    }

    private func didConnectTarget(_ peripheral: CBPeripheral) {
        targetLink = .connected
        stopRSSITimer()
        rssiTimer = Timer.scheduledTimer(withTimeInterval: Self.rssiReadInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let peripheral = self.targetPeripheral, peripheral.state == .connected else { return }
                peripheral.readRSSI()
            }
        }
    }

    private func stopRSSITimer() {
        rssiTimer?.invalidate()
        rssiTimer = nil
    }

    private func recordTargetMeasurement(_ rssi: Int) {
        guard rssi != Self.unavailableRSSI, rssi < 0 else { return }
        lastTargetRSSI = rssi
        onTargetMeasurement?(rssi)
    }

    private func pruneDevices() {
        let now = Date()
        devices = devices.filter { $0.key == targetID || now.timeIntervalSince($0.value.lastSeen) < Self.deviceRetention }
    }

    private func updateAvailability(from central: CBCentralManager) {
        let newValue: BluetoothAvailability
        switch central.state {
        case .poweredOn: newValue = .available
        case .poweredOff, .resetting: newValue = .poweredOff
        case .unauthorized: newValue = .unauthorized
        case .unsupported: newValue = .unsupported
        case .unknown: newValue = .unknown
        @unknown default: newValue = .unknown
        }
        if CBCentralManager.authorization == .denied || CBCentralManager.authorization == .restricted {
            availability = .unauthorized
        } else {
            availability = newValue
        }
        onAvailabilityChange?(availability)
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothMonitor: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            updateAvailability(from: central)
            if central.state == .poweredOn {
                startScanning()
                connectTargetIfPossible()
            } else {
                stopRSSITimer()
                targetPeripheral = nil
                targetLink = targetID == nil ? .notSelected : .searching
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
        let rssi = RSSI.intValue
        MainActor.assumeIsolated {
            let id = peripheral.identifier
            var device = devices[id] ?? BluetoothDevice(
                id: id, name: nil, rssi: rssi, lastSeen: Date(),
                advertisementCount: 0, manufacturerData: nil, isConnectable: isConnectable
            )
            device.name = name ?? device.name
            device.rssi = rssi
            device.lastSeen = Date()
            device.advertisementCount += 1
            device.manufacturerData = manufacturerData ?? device.manufacturerData
            device.isConnectable = isConnectable
            devices[id] = device

            guard id == targetID else { return }
            recordTargetMeasurement(rssi)
            if targetPeripheral == nil {
                targetPeripheral = peripheral
                connectTargetIfPossible()
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            guard peripheral.identifier == targetID else { return }
            didConnectTarget(peripheral)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        MainActor.assumeIsolated {
            guard peripheral.identifier == targetID else { return }
            stopRSSITimer()
            connectTargetIfPossible()
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        MainActor.assumeIsolated {
            guard peripheral.identifier == targetID else { return }
            // On repasse par le scan : le téléphone a peut-être changé d'adresse.
            targetPeripheral = nil
            targetLink = .searching
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothMonitor: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        let rssi = RSSI.intValue
        MainActor.assumeIsolated {
            guard error == nil, peripheral.identifier == targetID else { return }
            recordTargetMeasurement(rssi)
        }
    }
}
