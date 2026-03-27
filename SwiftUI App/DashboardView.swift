import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var showReceiverSheet = false
    @State private var showAmountSheet = false
    @State private var showSuccess = false

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            backgroundLayer
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    Text("Mike's Kindeks")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.96))
                    LazyVGrid(columns: columns, spacing: 14) {
                        if appState.selectedTab == .thanks {
                            thanksTiles
                        } else {
                            donationsTiles
                        }
                    }
                }
                .padding(18)
                .padding(.top, 8)
            }
            if showSuccess {
                successOverlay
            }
        }
        .sheet(isPresented: $showReceiverSheet) {
            ReceiverPickerSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showAmountSheet) {
            DonationsAmountSheet()
                .environmentObject(appState)
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: DashboardRoute.self) { route in
            switch route {
            case .history:
                HistoryView()
                    .environmentObject(appState)
            case .partners:
                PartnersView()
            case .settings:
                SettingsView()
                    .environmentObject(appState)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            CircleButton(icon: "chevron.left")
            Picker("Mode", selection: $appState.selectedTab) {
                ForEach(DashboardTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            CircleButton(icon: "person.crop.circle")
        }
    }

    @ViewBuilder
    private var thanksTiles: some View {
        GlassCard(action: appState.toggleAccepting) {
            VStack(alignment: .leading, spacing: 10) {
                Label(appState.isAccepting ? "Accepting" : "Start", systemImage: "bolt.heart")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.95))
                StatusPill(
                    title: appState.isAccepting ? "ON" : "OFF",
                    isActive: appState.isAccepting
                )
            }
        }

        GlassCard(action: { showReceiverSheet = true }) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Nearby", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.95))
                Text(nearbyTitle)
                    .foregroundStyle(.white.opacity(0.75))
                    .font(.subheadline)
            }
        }

        if appState.isAccepting {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Session", systemImage: "hourglass")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.95))
                    Text(formatTime(appState.sessionRemainingSeconds))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }

        GlassCard(action: sendThanks) {
            VStack(alignment: .leading, spacing: 10) {
                Label("SEND THANKS", systemImage: "paperplane.fill")
                    .font(.headline)
                    .foregroundStyle(canSendThanks ? .white : .white.opacity(0.45))
                Text(appState.selectedReceiver?.name ?? "Select receiver")
                    .foregroundStyle(.white.opacity(0.75))
                    .font(.subheadline)
            }
        }
        .opacity(canSendThanks ? 1 : 0.66)

        NavigationLink(value: DashboardRoute.history) {
            GlassCard {
                tileLabel("History", "clock.arrow.circlepath")
            }
        }
        .buttonStyle(.plain)

        NavigationLink(value: DashboardRoute.partners) {
            GlassCard {
                tileLabel("Partners", "person.3.fill")
            }
        }
        .buttonStyle(.plain)

        NavigationLink(value: DashboardRoute.settings) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    tileLabel("Silence", "bell.slash.fill")
                    StatusPill(title: appState.silenceMode ? "Enabled" : "Disabled", isActive: appState.silenceMode)
                }
            }
        }
        .buttonStyle(.plain)

        GlassCard {
            tileLabel("Widget", "square.grid.2x2")
        }
    }

    @ViewBuilder
    private var donationsTiles: some View {
        ForEach(appState.donationPresets) { preset in
            GlassCard(action: { appState.selectedDonationAmount = preset.amount }) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(String(format: "$%.0f", preset.amount), systemImage: "dollarsign.circle")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.95))
                    Text("Preset amount")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }

        GlassCard(action: { showAmountSheet = true }) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Choose your sum", systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.95))
                Text(String(format: "$%.0f selected", appState.selectedDonationAmount))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }

        GlassCard(action: { showReceiverSheet = true }) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Receiver", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.95))
                Text(appState.selectedReceiver?.name ?? "Select receiver")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }

        GlassCard(action: sendDonation) {
            VStack(alignment: .leading, spacing: 10) {
                Label("SEND", systemImage: "paperplane.fill")
                    .font(.headline)
                    .foregroundStyle(canSendDonation ? .white : .white.opacity(0.45))
                Text("Send selected amount")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .opacity(canSendDonation ? 1 : 0.66)

        GlassCard(action: appState.cancelDonation) {
            VStack(alignment: .leading, spacing: 10) {
                tileLabel("CANCEL", "xmark")
            }
        }
    }

    private var canSendThanks: Bool {
        appState.selectedReceiver != nil
    }

    private var canSendDonation: Bool {
        appState.selectedReceiver != nil
    }

    private var nearbyTitle: String {
        switch appState.nearbyState {
        case .idle:
            return "Searching..."
        case .searching:
            return "Searching..."
        case .found:
            return "Nearby active"
        }
    }

    private func sendThanks() {
        guard canSendThanks else {
            showReceiverSheet = true
            return
        }
        appState.sendThanks()
        showSuccessBurst()
    }

    private func sendDonation() {
        guard canSendDonation else {
            showReceiverSheet = true
            return
        }
        appState.sendDonation()
        showSuccessBurst()
    }

    private func showSuccessBurst() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.74)) {
            showSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.25)) {
                showSuccess = false
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    @ViewBuilder
    private func tileLabel(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.white.opacity(0.95))
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.11),
                    Color(red: 0.09, green: 0.05, blue: 0.14),
                    Color(red: 0.03, green: 0.03, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.1), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .blendMode(.screen)
            .blur(radius: 10)
        }
        .ignoresSafeArea()
    }

    private var successOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Sent")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(26)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .transition(.scale.combined(with: .opacity))
    }
}

private enum DashboardRoute: Hashable {
    case history
    case partners
    case settings
}

private struct CircleButton: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
            .frame(width: 34, height: 34)
            .background(.regularMaterial)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .clipShape(Circle())
    }
}
