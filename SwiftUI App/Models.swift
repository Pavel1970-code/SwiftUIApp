import Foundation
import SwiftUI
import Combine
import CoreBluetooth

/// Tab order in the dashboard segmented control: **left → right** = Donations, then Thanks.
enum DashboardTab: String, CaseIterable, Identifiable {
    case donations = "Donations"
    case thanks = "Thanks"

    var id: String { rawValue }

    /// Fixed UI order; use this in `Picker` instead of `allCases` so enum order can’t drift by accident.
    static let segmentOrder: [DashboardTab] = [.donations, .thanks]
}

enum NearbyState {
    case idle
    case searching
    case found
}

struct Receiver: Identifiable, Equatable {
    let id: UUID
    let name: String
    let icon: String
}

struct DonationPreset: Identifiable {
    let id = UUID()
    let amount: Int
}

enum HistoryEventType {
    case thanks
    case donation
}

enum HistoryEventDirection {
    case sent
    case received
}

struct HistoryEvent: Identifiable {
    let id = UUID()
    let type: HistoryEventType
    let direction: HistoryEventDirection
    let receiverId: UUID?
    let receiverLabel: String?
    let amount: Int?
    let timestamp: Date
}

@MainActor
final class AppState: ObservableObject {
    /// App opens on **Donations** (left segment). Do not default to `.thanks` unless product changes.
    @Published var selectedTab: DashboardTab = .donations
    @Published var isAccepting = false {
        didSet { handleAcceptingChanged() }
    }
    @Published var sessionRemainingSeconds = 0
    @Published var nearbyState: NearbyState = .idle
    @Published var selectedReceiver: Receiver?
    @Published var selectedGiftId: UInt8?
    @Published var pendingInvite: BLEInvite?
    @Published var silenceMode = false
    @Published var history: [HistoryEvent] = []

    @Published var receivers: [Receiver] = []

    let donationPresets: [DonationPreset] = [
        DonationPreset(amount: 1),
        DonationPreset(amount: 5)
    ]

    @Published var selectedDonationAmount: Int?

    private let ble = BLEGiftSessionManager.shared
    private var peripheralForReceiverId: [UUID: CBPeripheral] = [:]

    private var sessionTimer: AnyCancellable?
    private var nearbyWorkItem: DispatchWorkItem?

    init() {
        ble.onScanPeersChanged = { [weak self] peripherals in
            self?.updateNearbyReceivers(from: peripherals)
        }
        ble.onInviteReceived = { [weak self] invite in
            self?.handleInviteReceived(invite)
        }
    }

    func toggleAccepting() {
        isAccepting.toggle()
    }

    func sendThanks() {
        guard let invite = pendingInvite else { return }
        ble.sendThanks(invite)

        // Receiver side: we show "Nearby #1" as the sender label (MVP).
        let receiver = selectedReceiver
        history.insert(
            HistoryEvent(
                type: .thanks,
                direction: .sent,
                receiverId: receiver?.id,
                receiverLabel: receiver?.name,
                amount: nil,
                timestamp: Date()
            ),
            at: 0
        )

        pendingInvite = nil
        selectedReceiver = nil
        nearbyState = .searching
    }

    func sendDonation() {
        // Legacy mock method kept for compilation; MVP uses `sendDonationOverBLE()`.
    }

    func cancelDonation() {
        selectedGiftId = nil
        selectedDonationAmount = nil
        selectedReceiver = nil
        pendingInvite = nil
    }

    private func handleAcceptingChanged() {
        if isAccepting {
            startSession()
        } else {
            stopSession()
        }
    }

    private func startSession() {
        sessionRemainingSeconds = 2 * 60 * 60
        nearbyState = .searching
        pendingInvite = nil
        selectedReceiver = nil
        ble.setReceiverAccepting(true)
        startTimer()
    }

    private func stopSession() {
        sessionTimer?.cancel()
        sessionTimer = nil
        nearbyWorkItem?.cancel()
        nearbyWorkItem = nil
        sessionRemainingSeconds = 0
        nearbyState = .idle
        selectedReceiver = nil
        pendingInvite = nil
        ble.setReceiverAccepting(false)
    }

    private func startTimer() {
        sessionTimer?.cancel()
        sessionTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.isAccepting else { return }
                if self.sessionRemainingSeconds > 0 {
                    self.sessionRemainingSeconds -= 1
                }
                if self.sessionRemainingSeconds <= 0 {
                    self.isAccepting = false
                }
            }
    }

    private func scheduleNearbyFound() {
        nearbyWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isAccepting else { return }
            self.nearbyState = .found
        }
        nearbyWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: item)
    }

    // MARK: - BLE scanning helpers
    func startBLEScanning() {
        nearbyState = .searching
        ble.startScanning()
    }

    func stopBLEScanning() {
        ble.stopScanning()
        // Keep discovered peripheral mapping so we can connect right after selection.
        // UI list can be cleared later if needed.
        if !isAccepting {
            nearbyState = .idle
        } else {
            nearbyState = .searching
        }
    }

    private func updateNearbyReceivers(from peripherals: [CBPeripheral]) {
        peripheralForReceiverId.removeAll(keepingCapacity: true)
        let icons = ["circle.hexagongrid.fill", "sparkles", "waveform.path.ecg"]
        receivers = peripherals.prefix(3).enumerated().map { offset, peripheral in
            peripheralForReceiverId[peripheral.identifier] = peripheral
            return Receiver(
                id: peripheral.identifier,
                name: "Nearby #\(offset + 1)",
                icon: icons[offset % icons.count]
            )
        }
        nearbyState = receivers.isEmpty ? .searching : .found
    }

    private func handleInviteReceived(_ invite: BLEInvite) {
        pendingInvite = invite
        nearbyState = .found

        // MVP: on receiver we don't know which peer label (we just display a generic "Nearby #1").
        selectedReceiver = Receiver(id: UUID(), name: "Nearby #1", icon: "circle.hexagongrid.fill")
    }

    // MARK: - Donor send over BLE
    func sendDonationOverBLE() async -> Bool {
        guard let receiver = selectedReceiver else { return false }

        let eventKind: BLEInviteEventKind
        let value: UInt16
        if let giftId = selectedGiftId {
            eventKind = .gift
            value = UInt16(giftId)
        } else if let amount = selectedDonationAmount {
            eventKind = .money
            value = UInt16(amount * 100) // cents
        } else {
            return false
        }

        guard let peripheral = peripheralForReceiverId[receiver.id] else { return false }

        let txId = UInt32.random(in: 1...UInt32.max)
        let invite = BLEInvite(txId: txId, eventKind: eventKind, value: value)

        let ok = await withCheckedContinuation { continuation in
            ble.sendInvite(to: peripheral, invite: invite) { success in
                continuation.resume(returning: success)
            }
        }

        guard ok else { return false }

        history.insert(
            HistoryEvent(
                type: .donation,
                direction: .sent,
                receiverId: receiver.id,
                receiverLabel: receiver.name,
                amount: selectedGiftId == nil ? selectedDonationAmount : nil,
                timestamp: Date()
            ),
            at: 0
        )

        // Session ends (MVP): clear draft and close selection.
        selectedReceiver = nil
        selectedDonationAmount = nil
        selectedGiftId = nil
        nearbyState = .idle

        return true
    }
}

// MARK: - BLE MVP transport (embedded so it compiles in this target)
enum BLEInviteEventKind: UInt8 {
    case gift = 1
    case money = 2
}

struct BLEInvite {
    let txId: UInt32
    let eventKind: BLEInviteEventKind
    let value: UInt16
}

final class BLEGiftSessionManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate {
    static let shared = BLEGiftSessionManager()

    // Fixed UUIDs for this MVP. They only need to be consistent across both apps.
    private let serviceUUID = CBUUID(string: "0000A001-0000-1000-8000-00805F9B34FB")
    private let rxCharUUID = CBUUID(string: "0000A002-0000-1000-8000-00805F9B34FB") // write (donor -> receiver)
    private let txCharUUID = CBUUID(string: "0000A003-0000-1000-8000-00805F9B34FB") // notify (receiver -> donor)

    private let centralManager: CBCentralManager
    private let peripheralManager: CBPeripheralManager

    // MARK: - Scan state
    private(set) var scanOrder: [UUID] = []
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var isScanning = false

    var onScanPeersChanged: (([CBPeripheral]) -> Void)?

    // MARK: - Receiver state (advertising)
    private var rxCharacteristic: CBMutableCharacteristic?
    private var txCharacteristic: CBMutableCharacteristic?
    private var pendingInvite: BLEInvite?
    private var receiverAccepting = false
    private var receiverServiceAdded = false
    private var shouldStartAdvertisingAfterAddService = false

    var onInviteReceived: ((BLEInvite) -> Void)?

    // MARK: - Donor state (connecting + waiting THANKS)
    private var pendingThanksHandlers: [UInt32: (Bool) -> Void] = [:]
    private var pendingInviteToSend: (peripheral: CBPeripheral, invite: BLEInvite)?

    private var connectedPeripheral: CBPeripheral?
    private var txForConnected: CBCharacteristic?
    private var rxForConnected: CBCharacteristic?

    private override init() {
        centralManager = CBCentralManager(delegate: nil, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: nil, queue: nil)
        super.init()
        centralManager.delegate = self
        peripheralManager.delegate = self
    }

    // MARK: Public API
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        stopScanning()
        isScanning = true
        scanOrder.removeAll(keepingCapacity: true)
        discoveredPeripherals.removeAll(keepingCapacity: true)
        onScanPeersChanged?([])
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }

    func setReceiverAccepting(_ accepting: Bool) {
        receiverAccepting = accepting
        if accepting {
            ensurePeripheralService()
            if receiverServiceAdded {
                tryStartAdvertising()
            } else {
                shouldStartAdvertisingAfterAddService = true
            }
        } else {
            peripheralManager.stopAdvertising()
            pendingInvite = nil
            shouldStartAdvertisingAfterAddService = false
        }
    }

    func sendInvite(
        to peripheral: CBPeripheral,
        invite: BLEInvite,
        timeoutSeconds: TimeInterval = 30,
        onThanks: @escaping (Bool) -> Void
    ) {
        stopConnectionState()
        pendingThanksHandlers[invite.txId] = onThanks
        pendingInviteToSend = (peripheral: peripheral, invite: invite)

        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)

        // Hard timeout: receiver might disappear before tapping THANKS.
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds) { [weak self] in
            guard let self else { return }
            if self.pendingThanksHandlers.removeValue(forKey: invite.txId) != nil {
                onThanks(false)
            }
        }
    }

    func sendThanks(_ invite: BLEInvite) {
        guard let txCharacteristic, peripheralManager.state == .poweredOn else { return }
        let data = encodeThanks(version: 1, type: 3, txId: invite.txId, thanksCode: 0, reserved: 0)
        peripheralManager.updateValue(data, for: txCharacteristic, onSubscribedCentrals: nil)
    }

    // MARK: - Peripheral (receiver) setup
    private func ensurePeripheralService() {
        guard rxCharacteristic == nil, txCharacteristic == nil else { return }

        let rx = CBMutableCharacteristic(
            type: rxCharUUID,
            properties: [.write],
            value: nil,
            permissions: [.writeable]
        )
        let tx = CBMutableCharacteristic(
            type: txCharUUID,
            properties: [.notify],
            value: nil,
            permissions: [.readable]
        )

        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [rx, tx]

        rxCharacteristic = rx
        txCharacteristic = tx

        peripheralManager.add(service)
    }

    private func tryStartAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        guard receiverServiceAdded else { return }
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID]
        ])
    }

    // MARK: - Helpers
    private func stopConnectionState() {
        connectedPeripheral = nil
        txForConnected = nil
        rxForConnected = nil
    }

    private func encodeInvite(
        version: UInt8,
        type: UInt8,
        txId: UInt32,
        eventKind: BLEInviteEventKind,
        value: UInt16
    ) -> Data {
        // INVITE frame:
        // version(1) + type(1) + txId(4) + eventKind(1) + value(2) + reserved(1) = 10 bytes
        var d = Data()
        d.reserveCapacity(10)
        d.append(version)
        d.append(type)
        d.append(contentsOf: bytesLE(txId))
        d.append(eventKind.rawValue)
        d.append(contentsOf: bytesLE(value))
        d.append(0) // reserved
        return d
    }

    private func encodeThanks(version: UInt8, type: UInt8, txId: UInt32, thanksCode: UInt8, reserved: UInt8) -> Data {
        // THANKS frame:
        // version(1) + type(1) + txId(4) + thanksCode(1) + reserved(1) = 8 bytes
        var d = Data()
        d.reserveCapacity(8)
        d.append(version)
        d.append(type)
        d.append(contentsOf: bytesLE(txId))
        d.append(thanksCode)
        d.append(reserved)
        return d
    }

    private func decodeInvite(_ data: Data) -> BLEInvite? {
        // Expect 10 bytes.
        guard data.count == 10 else { return nil }
        let bytes = [UInt8](data)
        let version = bytes[0]
        let type = bytes[1]
        guard version == 1, type == 1 else { return nil }
        let txId = UInt32(bytes[2]) |
            (UInt32(bytes[3]) << 8) |
            (UInt32(bytes[4]) << 16) |
            (UInt32(bytes[5]) << 24)
        guard let kind = BLEInviteEventKind(rawValue: bytes[6]) else { return nil }
        let value = UInt16(bytes[7]) | (UInt16(bytes[8]) << 8)
        return BLEInvite(txId: txId, eventKind: kind, value: value)
    }

    private func bytesLE<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        var le = value.littleEndian
        return withUnsafeBytes(of: &le) { rawBuf in
            Array(rawBuf.bindMemory(to: UInt8.self))
        }
    }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn { return }
        if isScanning {
            startScanning()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let pid = peripheral.identifier
        if discoveredPeripherals[pid] == nil {
            scanOrder.append(pid)
            discoveredPeripherals[pid] = peripheral
            let peers = scanOrder.compactMap { discoveredPeripherals[$0] }
            onScanPeersChanged?(peers)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        central.cancelPeripheralConnection(peripheral)
        stopConnectionState()
    }

    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else { return }
        peripheral.discoverCharacteristics([rxCharUUID, txCharUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        guard let chars = service.characteristics else { return }
        for c in chars {
            if c.uuid == rxCharUUID { rxForConnected = c }
            if c.uuid == txCharUUID { txForConnected = c }
        }

        if let txForConnected {
            peripheral.setNotifyValue(true, for: txForConnected)
        }

        guard let rxForConnected else { return }
        guard let pendingInviteToSend else { return }
        guard pendingInviteToSend.peripheral.identifier == peripheral.identifier else { return }

        let inviteData = encodeInvite(
            version: 1,
            type: 1,
            txId: pendingInviteToSend.invite.txId,
            eventKind: pendingInviteToSend.invite.eventKind,
            value: pendingInviteToSend.invite.value
        )

        peripheral.writeValue(inviteData, for: rxForConnected, type: .withResponse)
        self.pendingInviteToSend = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else { return }
        guard characteristic.uuid == txCharUUID else { return }
        guard let data = characteristic.value else { return }

        guard data.count == 8 else { return }
        let bytes = [UInt8](data)
        let version = bytes[0]
        let type = bytes[1]
        guard version == 1, type == 3 else { return }

        let txId = UInt32(bytes[2]) |
            (UInt32(bytes[3]) << 8) |
            (UInt32(bytes[4]) << 16) |
            (UInt32(bytes[5]) << 24)

        if let handler = pendingThanksHandlers.removeValue(forKey: txId) {
            handler(true)
            centralManager.cancelPeripheralConnection(peripheral)
            stopConnectionState()
        }
    }

    // MARK: - CBPeripheralManagerDelegate
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {}
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {}

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        receiverServiceAdded = (error == nil)
        if receiverAccepting, receiverServiceAdded, shouldStartAdvertisingAfterAddService {
            shouldStartAdvertisingAfterAddService = false
            tryStartAdvertising()
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        for req in requests {
            guard req.characteristic.uuid == rxCharUUID else {
                peripheral.respond(to: req, withResult: .attributeNotFound)
                continue
            }
            guard let value = req.value else {
                peripheral.respond(to: req, withResult: .invalidAttributeValueLength)
                continue
            }

            guard let invite = decodeInvite(value) else {
                peripheral.respond(to: req, withResult: .unlikelyError)
                continue
            }

            pendingInvite = invite
            onInviteReceived?(invite)
            peripheral.respond(to: req, withResult: .success)
        }
    }
}
