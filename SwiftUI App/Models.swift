import Foundation
import SwiftUI
import Combine

enum DashboardTab: String, CaseIterable, Identifiable {
    case thanks = "Thanks"
    case donations = "Donations"

    var id: String { rawValue }
}

enum NearbyState {
    case idle
    case searching
    case found
}

struct Receiver: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let icon: String
}

struct DonationPreset: Identifiable {
    let id = UUID()
    let amount: Double
}

struct HistoryEvent: Identifiable {
    let id = UUID()
    let title: String
    let details: String
    let timestamp: Date
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: DashboardTab = .thanks
    @Published var isAccepting = false {
        didSet { handleAcceptingChanged() }
    }
    @Published var sessionRemainingSeconds = 0
    @Published var nearbyState: NearbyState = .idle
    @Published var selectedReceiver: Receiver?
    @Published var silenceMode = false
    @Published var history: [HistoryEvent] = [
        HistoryEvent(title: "Thank sent", details: "To Nova", timestamp: Date().addingTimeInterval(-3600)),
        HistoryEvent(title: "Donation sent", details: "$5 to Orbit", timestamp: Date().addingTimeInterval(-7800))
    ]

    let receivers: [Receiver] = [
        Receiver(name: "Nova", icon: "circle.hexagongrid.fill"),
        Receiver(name: "Orbit", icon: "sparkles"),
        Receiver(name: "Pulse", icon: "waveform.path.ecg")
    ]

    let donationPresets: [DonationPreset] = [
        DonationPreset(amount: 1),
        DonationPreset(amount: 5)
    ]

    @Published var selectedDonationAmount: Double = 1

    private var sessionTimer: AnyCancellable?
    private var nearbyWorkItem: DispatchWorkItem?

    func toggleAccepting() {
        isAccepting.toggle()
    }

    func sendThanks() {
        guard let receiver = selectedReceiver else { return }
        history.insert(
            HistoryEvent(title: "Thank sent", details: "To \(receiver.name)", timestamp: Date()),
            at: 0
        )
        selectedReceiver = nil
    }

    func sendDonation() {
        guard let receiver = selectedReceiver else { return }
        let amountText = String(format: "$%.0f", selectedDonationAmount)
        history.insert(
            HistoryEvent(title: "Donation sent", details: "\(amountText) to \(receiver.name)", timestamp: Date()),
            at: 0
        )
        selectedReceiver = nil
        selectedDonationAmount = donationPresets.first?.amount ?? 1
    }

    func cancelDonation() {
        selectedDonationAmount = donationPresets.first?.amount ?? 1
        selectedReceiver = nil
    }

    private func handleAcceptingChanged() {
        if isAccepting {
            startSession()
        } else {
            stopSession()
        }
    }

    private func startSession() {
        sessionRemainingSeconds = max(sessionRemainingSeconds, 2 * 60 * 60)
        nearbyState = .searching
        startTimer()
        scheduleNearbyFound()
    }

    private func stopSession() {
        sessionTimer?.cancel()
        sessionTimer = nil
        nearbyWorkItem?.cancel()
        nearbyWorkItem = nil
        sessionRemainingSeconds = 0
        nearbyState = .idle
        selectedReceiver = nil
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: item)
    }
}
