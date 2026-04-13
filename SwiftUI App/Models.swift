import Foundation
import SwiftUI
import Combine
import CoreBluetooth
import UIKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

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
    let avatarData: Data?
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

struct BLELocalProfile {
    let nickname: String
    let avatarData: Data?
}

enum LocalProfileBridge {
    private static let key = "local_profile_v1"

    private struct StoredProfile: Codable {
        let id: UUID
        let displayName: String
        let avatarData: Data?
        let createdAt: Date
    }

    static func load() -> BLELocalProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        guard let decoded = try? JSONDecoder().decode(StoredProfile.self, from: data) else { return nil }
        return BLELocalProfile(
            nickname: decoded.displayName,
            avatarData: normalizedAvatar(decoded.avatarData)
        )
    }

    private static func normalizedAvatar(_ raw: Data?) -> Data? {
        guard let raw, let image = UIImage(data: raw) else { return nil }
        let target = CGSize(width: 64, height: 64)
        let renderer = UIGraphicsImageRenderer(size: target)
        let thumb = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return thumb.jpegData(compressionQuality: 0.62)
    }
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
    private let statsStore = FirebaseStatsStore.shared
    private var peripheralForReceiverId: [UUID: CBPeripheral] = [:]
    private var profileByPeripheralId: [UUID: (nickname: String, avatarData: Data?)] = [:]

    private var sessionTimer: AnyCancellable?
    private var nearbyWorkItem: DispatchWorkItem?
    private let actionCooldownSeconds: TimeInterval = 15
    private var nextOutgoingAllowedAt: Date = .distantPast

    init() {
        ble.onScanPeersChanged = { [weak self] peripherals in
            self?.updateNearbyReceivers(from: peripherals)
        }
        ble.onInviteReceived = { [weak self] invite in
            self?.handleInviteReceived(invite)
        }
        ble.onProfileReceived = { [weak self] peripheralId, nickname, avatarData in
            self?.handlePeerProfile(
                peripheralId: peripheralId,
                nickname: nickname,
                avatarData: avatarData
            )
        }
        ble.profileProvider = {
            LocalProfileBridge.load()
        }
    }

    func toggleAccepting() {
        isAccepting.toggle()
    }

    func sendThanks() {
        guard let invite = pendingInvite else { return }
        ble.sendThanks(invite)
        registerActionCooldown()
        statsStore.trackThanksSent()

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
        sessionRemainingSeconds = 45 * 60
        nearbyState = .searching
        pendingInvite = nil
        selectedReceiver = nil
        nextOutgoingAllowedAt = .distantPast
        ble.setReceiverAccepting(true)
        ble.startScanning()
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
        ble.stopScanning()
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
        guard isAccepting else { return }
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

    private func canStartOutgoingAction() -> Bool {
        guard isAccepting else { return false }
        guard pendingInvite == nil else { return false } // Prioritize incoming actions first.
        return Date() >= nextOutgoingAllowedAt
    }

    private func registerActionCooldown() {
        nextOutgoingAllowedAt = Date().addingTimeInterval(actionCooldownSeconds)
    }

    private func updateNearbyReceivers(from peripherals: [CBPeripheral]) {
        peripheralForReceiverId.removeAll(keepingCapacity: true)
        let icons = ["circle.hexagongrid.fill", "sparkles", "waveform.path.ecg"]
        receivers = peripherals.prefix(3).enumerated().map { offset, peripheral in
            peripheralForReceiverId[peripheral.identifier] = peripheral
            let profile = profileByPeripheralId[peripheral.identifier]
            return Receiver(
                id: peripheral.identifier,
                name: profile?.nickname ?? "Nearby #\(offset + 1)",
                icon: icons[offset % icons.count],
                avatarData: profile?.avatarData
            )
        }
        nearbyState = receivers.isEmpty ? .searching : .found
    }

    private func handleInviteReceived(_ invite: BLEInvite) {
        pendingInvite = invite
        nearbyState = .found
        registerActionCooldown()

        // MVP: on receiver we don't know which peer label (we just display a generic "Nearby #1").
        selectedReceiver = Receiver(
            id: UUID(),
            name: "Nearby #1",
            icon: "circle.hexagongrid.fill",
            avatarData: nil
        )
    }

    private func handlePeerProfile(peripheralId: UUID, nickname: String, avatarData: Data?) {
        profileByPeripheralId[peripheralId] = (nickname: nickname, avatarData: avatarData)
        receivers = receivers.map { receiver in
            guard receiver.id == peripheralId else { return receiver }
            return Receiver(
                id: receiver.id,
                name: nickname,
                icon: receiver.icon,
                avatarData: avatarData
            )
        }
    }

    // MARK: - Donor send over BLE
    func sendDonationOverBLE() async -> Bool {
        guard canStartOutgoingAction() else { return false }
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
        registerActionCooldown()
        if eventKind == .money {
            statsStore.trackDonation(amountCents: Int(value))
        }

        return true
    }
}

@MainActor
final class FirebaseStatsStore {
    static let shared = FirebaseStatsStore()

    private init() {}

    func trackThanksSent() {
        #if canImport(FirebaseFirestore)
        let payload: [String: Any] = [
            "thanks_sent_total": FieldValue.increment(Int64(1)),
            "updated_at": FieldValue.serverTimestamp()
        ]
        Firestore.firestore()
            .collection("stats")
            .document("global")
            .setData(payload, merge: true)
        #endif
    }

    func trackDonation(amountCents: Int) {
        guard amountCents > 0 else { return }
        #if canImport(FirebaseFirestore)
        var payload: [String: Any] = [
            "updated_at": FieldValue.serverTimestamp()
        ]
        if amountCents == 100 {
            payload["donation_1usd_total"] = FieldValue.increment(Int64(1))
        } else {
            payload["donation_custom_total"] = FieldValue.increment(Int64(1))
            payload["donation_amount_cents_total"] = FieldValue.increment(Int64(amountCents))
        }
        Firestore.firestore()
            .collection("stats")
            .document("global")
            .setData(payload, merge: true)
        #endif
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
    var onProfileReceived: ((UUID, String, Data?) -> Void)?
    var profileProvider: (() -> BLELocalProfile?)?

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
    private var outgoingNotifyQueue: [Data] = []
    private var incomingProfileStateByPeripheral: [UUID: IncomingProfileState] = [:]

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
        let localName = profileProvider?()?.nickname ?? "Nearby"
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: String(localName.prefix(24))
        ])
    }

    // MARK: - Helpers
    private func stopConnectionState() {
        connectedPeripheral = nil
        txForConnected = nil
        rxForConnected = nil
    }

    private struct IncomingProfileState {
        let nickname: String
        let totalAvatarBytes: Int
        var collectedAvatar: Data
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

    // PROFILE_START frame:
    // version(1) + type(1=4) + nameLen(1) + name + avatarTotalLen(2)
    private func encodeProfileStart(nickname: String, avatarTotalLen: UInt16) -> Data {
        let nameData = Data(nickname.utf8.prefix(60))
        var d = Data()
        d.reserveCapacity(1 + 1 + 1 + nameData.count + 2)
        d.append(1) // version
        d.append(4) // type profile-start
        d.append(UInt8(nameData.count))
        d.append(nameData)
        d.append(contentsOf: bytesLE(avatarTotalLen))
        return d
    }

    // PROFILE_CHUNK frame:
    // version(1) + type(1=5) + chunkLen(1) + chunk
    private func encodeProfileChunk(_ chunk: Data) -> Data {
        var d = Data()
        d.reserveCapacity(3 + chunk.count)
        d.append(1) // version
        d.append(5) // type profile-chunk
        d.append(UInt8(chunk.count))
        d.append(chunk)
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

    private func enqueueProfileFrames() {
        guard let profile = profileProvider?() else { return }
        let avatar = profile.avatarData ?? Data()
        let cappedAvatar = Data(avatar.prefix(1024))
        let start = encodeProfileStart(
            nickname: profile.nickname,
            avatarTotalLen: UInt16(cappedAvatar.count)
        )
        outgoingNotifyQueue.append(start)

        var cursor = 0
        let chunkSize = 140
        while cursor < cappedAvatar.count {
            let end = min(cursor + chunkSize, cappedAvatar.count)
            let chunk = cappedAvatar[cursor..<end]
            outgoingNotifyQueue.append(encodeProfileChunk(Data(chunk)))
            cursor = end
        }
        flushNotifyQueueIfPossible()
    }

    private func flushNotifyQueueIfPossible() {
        guard let txCharacteristic else { return }
        while !outgoingNotifyQueue.isEmpty {
            let next = outgoingNotifyQueue[0]
            let sent = peripheralManager.updateValue(next, for: txCharacteristic, onSubscribedCentrals: nil)
            if sent {
                outgoingNotifyQueue.removeFirst()
            } else {
                break
            }
        }
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

        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            onProfileReceived?(pid, localName, nil)
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
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return }
        let version = bytes[0]
        let type = bytes[1]
        guard version == 1 else { return }

        if type == 3 {
            guard data.count == 8 else { return }
            let txId = UInt32(bytes[2]) |
                (UInt32(bytes[3]) << 8) |
                (UInt32(bytes[4]) << 16) |
                (UInt32(bytes[5]) << 24)

            if let handler = pendingThanksHandlers.removeValue(forKey: txId) {
                handler(true)
                centralManager.cancelPeripheralConnection(peripheral)
                stopConnectionState()
            }
            return
        }

        if type == 4 {
            // PROFILE_START
            guard bytes.count >= 5 else { return }
            let nameLen = Int(bytes[2])
            let header = 3 + nameLen + 2
            guard bytes.count >= header else { return }
            let nameBytes = bytes[3..<(3 + nameLen)]
            let nickname = String(decoding: nameBytes, as: UTF8.self)
            let totalLenIndex = 3 + nameLen
            let totalAvatarLen = Int(UInt16(bytes[totalLenIndex]) | (UInt16(bytes[totalLenIndex + 1]) << 8))
            incomingProfileStateByPeripheral[peripheral.identifier] = IncomingProfileState(
                nickname: nickname.isEmpty ? "Nearby" : nickname,
                totalAvatarBytes: totalAvatarLen,
                collectedAvatar: Data()
            )
            if totalAvatarLen == 0 {
                onProfileReceived?(peripheral.identifier, nickname.isEmpty ? "Nearby" : nickname, nil)
                incomingProfileStateByPeripheral[peripheral.identifier] = nil
            }
            return
        }

        if type == 5 {
            // PROFILE_CHUNK
            guard var state = incomingProfileStateByPeripheral[peripheral.identifier] else { return }
            guard bytes.count >= 3 else { return }
            let chunkLen = Int(bytes[2])
            guard bytes.count >= 3 + chunkLen else { return }
            state.collectedAvatar.append(contentsOf: bytes[3..<(3 + chunkLen)])
            if state.collectedAvatar.count >= state.totalAvatarBytes {
                let avatar = state.totalAvatarBytes > 0 ? state.collectedAvatar.prefix(state.totalAvatarBytes) : Data()
                onProfileReceived?(peripheral.identifier, state.nickname, avatar.isEmpty ? nil : Data(avatar))
                incomingProfileStateByPeripheral[peripheral.identifier] = nil
            } else {
                incomingProfileStateByPeripheral[peripheral.identifier] = state
            }
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

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard characteristic.uuid == txCharUUID else { return }
        enqueueProfileFrames()
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        flushNotifyQueueIfPossible()
    }
}
