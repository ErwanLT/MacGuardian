import Foundation

/// Informations qu'une application tierce obtient réellement sur un périphérique BLE.
///
/// L'`id` est l'identifiant Core Bluetooth : il dépend de l'adresse BLE, qui peut changer
/// pour un iPhone (adresses privées aléatoires). Ne pas le considérer comme permanent.
struct BluetoothDevice: Identifiable, Equatable {
    let id: UUID
    var name: String?
    var rssi: Int
    var lastSeen: Date
    var advertisementCount: Int
    var manufacturerData: Data?
    var isConnectable: Bool

    /// Company ID Apple (0x004C) en tête des données constructeur.
    var isApple: Bool {
        guard let data = manufacturerData, data.count >= 2 else { return false }
        return data[data.startIndex] == 0x4C && data[data.startIndex + 1] == 0x00
    }

    /// Type de message Continuity Apple, indicatif pour aider l'utilisateur à reconnaître son iPhone.
    var appleMessageHint: String? {
        guard isApple, let data = manufacturerData, data.count >= 3 else { return nil }
        switch data[data.startIndex + 2] {
        case 0x10: return "Nearby Info (iPhone, Mac, Watch…)"
        case 0x0F: return "Nearby Action"
        case 0x0C: return "Handoff"
        case 0x07: return "Écouteurs"
        case 0x09: return "AirPlay"
        case 0x12: return "Localiser"
        case 0x02: return "iBeacon"
        case let type: return String(format: "Apple (type 0x%02X)", type)
        }
    }

    var displayName: String {
        name ?? appleMessageHint ?? "Appareil sans nom"
    }

    var manufacturerDataHex: String {
        manufacturerData?.map { String(format: "%02X", $0) }.joined(separator: " ") ?? "—"
    }
}
