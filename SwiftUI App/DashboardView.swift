import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    let profileAvatarData: Data?

    @State private var showReceiverSheet = false
    @State private var showAmountSheet = false
    @State private var showDailySheet = false
    @State private var showSuccess = false
    @State private var showNearbyHint = false
    @State private var nearbyHintText = "Start session and wait for nearby active"

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
            if showNearbyHint {
                VStack {
                    Spacer()
                    nearbyHintOverlay
                        .padding(.bottom, 24)
                }
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
        .sheet(isPresented: $showDailySheet) {
            DailyPlaceholderSheet()
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: DashboardRoute.self) { route in
            switch route {
            case .aura:
                AuraView()
                    .environmentObject(appState)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            CircleButton(icon: "chevron.left")
            Picker("Mode", selection: $appState.selectedTab) {
                ForEach(DashboardTab.segmentOrder) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            ProfileAvatarBadge(avatarData: profileAvatarData)
        }
    }

    @ViewBuilder
    private var thanksTiles: some View {
        // Row 1 Left — toggle “accepting” + session timer / nearby pipeline
        GlassCard(action: appState.toggleAccepting) {
            VStack(alignment: .leading, spacing: 8) {
                tileLabel("Session", "bolt.heart")
                StatusPill(
                    title: appState.isAccepting ? "ON" : "OFF",
                    isActive: appState.isAccepting
                )
                Text(thanksSessionCaption)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Session")
            .accessibilityHint("Turns receiving thanks on or off for this timed session.")
        }

        // Row 1 Right — placeholder for future daily summary
        GlassCard(action: { showDailySheet = true }) {
            VStack(alignment: .leading, spacing: 8) {
                tileLabel("Daily", "sun.max.fill")
                Text("Daily recap & streak")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Preview · not connected yet")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Daily")
            .accessibilityHint("Opens a placeholder for daily mode.")
        }

        // Row 2 Left — quick send thanks (same receiver as Nearby)
        GlassCard(action: handleDoubleTap) {
            VStack(alignment: .leading, spacing: 8) {
                tileLabel("Quick thanks", "hand.tap.fill")
                Text("Send without a separate send button")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text(doubleTapSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quick thanks")
            .accessibilityHint(doubleTapSubtitle)
        }

        // Row 2 Right — MVP placeholder (no manual selection)
        GlassCard(isDisabled: true) {
            VStack(alignment: .leading, spacing: 8) {
                tileLabel("Nearby receiver", "dot.radiowaves.left.and.right")
                Text("Tap Quick thanks when you receive an invite")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text(nearbySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Nearby receiver")
            .accessibilityHint("Disabled in MVP; response goes to the connected donor.")
        }

        // Row 3 Left — read-only countdown mirror
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                tileLabel("Time left", "hourglass")
                Text(sessionEndsSecondaryLine)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text(sessionEndsDisplay)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Time left in session")
            .accessibilityValue(sessionEndsDisplay + ", " + sessionEndsSecondaryLine)
        }

        // Row 3 Right — history, silence, partners, widget
        NavigationLink(value: DashboardRoute.aura) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    tileLabel("Your Aura", "sparkles")
                    Text("History · partners · silence · widget")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Private activity & settings")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Your Aura")
                .accessibilityHint("Opens history, partners placeholder, silence toggle, and widget info.")
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var donationsTiles: some View {
        // Row 1 Left — mock goal + opens same receiver picker as Gift Two
        GlassCard(action: {
            appState.selectedGiftId = 0
            appState.selectedDonationAmount = nil
            showReceiverSheet = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                tileLabel("Gift goal 1", "gift.fill")
                Text("Placeholder artwork · mock")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text("Pick who receives the donation")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(giftSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Gift goal 1")
            .accessibilityHint("Opens the receiver list. Same recipient is used for the whole donation flow.")
        }

        // Row 1 Right
        GlassCard(action: {
            appState.selectedGiftId = 1
            appState.selectedDonationAmount = nil
            showReceiverSheet = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                tileLabel("Gift goal 2", "star.circle.fill")
                Text("Placeholder artwork · mock")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text("Pick who receives the donation")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(giftSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Gift goal 2")
            .accessibilityHint("Opens the receiver list. Same recipient as Gift goal 1.")
        }

        // Row 2 Left — preset amount
        GlassCard(action: {
            appState.selectedGiftId = nil
            appState.selectedDonationAmount = 1
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Label("$1", systemImage: "dollarsign.circle")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.95))
                Text("Quick preset")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text(donationPresetStatusLine)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("One dollar preset")
            .accessibilityValue(donationPresetStatusLine)
        }

        // Row 2 Right — custom amount sheet
        GlassCard(action: { showAmountSheet = true }) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Choose your sum", systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.95))
                Text("Slider mock · $1–$50")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text(donationAmountSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Choose donation amount")
            .accessibilityHint("Opens a sheet to set a custom amount.")
        }

        // Row 3 Left — clear draft
        GlassCard(action: appState.cancelDonation) {
            VStack(alignment: .leading, spacing: 8) {
                tileLabel("CANCEL", "xmark")
                Text("Clears amount & receiver")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Does not send anything")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cancel")
            .accessibilityHint("Resets the selected amount and receiver.")
        }

        // Row 3 Right — confirm + history entry (mock)
        GlassCard(action: sendDonation, isDisabled: !canSendDonation) {
            VStack(alignment: .leading, spacing: 8) {
                Label("SEND", systemImage: "paperplane.fill")
                    .font(.headline)
                    .foregroundStyle(canSendDonation ? .white : .white.opacity(0.45))
                Text("Requires amount + receiver")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text(sendDonationSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Send donation")
            .accessibilityHint(sendDonationSubtitle)
        }
    }

    private var donationPresetStatusLine: String {
        appState.selectedDonationAmount == 1 ? "Selected for this send" : "Tap to use $1"
    }

    private var canSendDonation: Bool {
        guard appState.selectedReceiver != nil else { return false }
        return appState.selectedGiftId != nil || appState.selectedDonationAmount != nil
    }

    private var canOpenNearbyPicker: Bool {
        appState.isAccepting && appState.nearbyState == .found
    }

    private var thanksSessionCaption: String {
        if appState.isAccepting {
            return "Timed session · tap to stop accepting thanks."
        }
        return "Starts a session and looks for nearby receivers."
    }

    private var nearbySubtitle: String {
        if appState.pendingInvite != nil {
            return "Invite received · tap Quick thanks"
        }
        switch appState.nearbyState {
        case .idle:
            return "Session off"
        case .searching:
            return "Searching nearby…"
        case .found:
            return "Invite received · tap Quick thanks"
        }
    }

    private var doubleTapSubtitle: String {
        if appState.isAccepting && appState.pendingInvite != nil {
            return "Tap to send thanks now"
        }
        if !appState.isAccepting {
            return "Turn Session on first"
        }
        return "Waiting for an invite"
    }

    private var sessionEndsSecondaryLine: String {
        if !appState.isAccepting {
            return "No active session"
        }
        return "Remaining in this session"
    }

    private var giftSubtitle: String {
        if let receiver = appState.selectedReceiver {
            return "Receiver: \(receiver.name)"
        }
        return "No receiver yet"
    }

    private var sendDonationSubtitle: String {
        if appState.selectedReceiver == nil {
            return "Choose a receiver via a gift goal tile"
        }
        if appState.selectedGiftId == nil && appState.selectedDonationAmount == nil {
            return "Pick a gift tile or choose your sum"
        }
        return "Ready · send over BLE (MVP)"
    }

    private func handleDoubleTap() {
        if appState.isAccepting && appState.pendingInvite != nil {
            appState.sendThanks()
            showSuccessBurst()
        } else if appState.isAccepting {
            showHint("Waiting for a nearby donation invite")
        } else {
            showHint("Start session first")
        }
    }

    private func handleNearbyTap() {
        if canOpenNearbyPicker {
            showReceiverSheet = true
        } else {
            showHint(nearbyUnavailableHint)
        }
    }

    private var nearbyUnavailableHint: String {
        if !appState.isAccepting {
            return "Turn Session on first"
        }
        if appState.nearbyState == .searching {
            return "Wait until nearby is ready"
        }
        return "Nearby unavailable right now"
    }

    private func sendDonation() {
        Task { @MainActor in
            let ok = await appState.sendDonationOverBLE()
            if ok {
                showSuccessBurst()
            } else {
                showHint("Could not deliver donation (timeout)")
            }
        }
    }

    private func showHint(_ text: String) {
        nearbyHintText = text
        withAnimation(.easeOut(duration: 0.2)) {
            showNearbyHint = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                showNearbyHint = false
            }
        }
    }

    private func showSuccessBurst() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.74)) {
            showSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.25)) {
                showSuccess = false
            }
        }
    }

    private var donationAmountSubtitle: String {
        if let amount = appState.selectedDonationAmount {
            return "$\(amount) selected"
        }
        return "No amount selected"
    }

    private var sessionEndsDisplay: String {
        guard appState.isAccepting else { return "—" }
        let seconds = appState.sessionRemainingSeconds
        if seconds <= 0 { return "0h" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
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

    private var nearbyHintOverlay: some View {
        Text(nearbyHintText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .transition(.opacity)
    }
}

private enum DashboardRoute: Hashable {
    case aura
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

private struct ProfileAvatarBadge: View {
    let avatarData: Data?

    var body: some View {
        Group {
            if let avatarData, let image = UIImage(data: avatarData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .frame(width: 34, height: 34)
        .background(.regularMaterial)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .clipShape(Circle())
    }
}

private struct DailyPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.yellow)
                Text("Daily mode (coming soon)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
