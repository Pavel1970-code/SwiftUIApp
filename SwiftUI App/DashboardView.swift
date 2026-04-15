import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let context: KindeksDashboardContext
    let profileAvatarData: Data?
    /// Open a peer’s Kindeks (same grid) from the receiver list.
    var onViewPeerKindeks: ((Receiver) -> Void)? = nil

    @State private var showAmountSheet = false
    @State private var showDailySheet = false
    @State private var showAddGoalSheet = false
    @State private var showSuccess = false
    @State private var showNearbyHint = false
    @State private var nearbyHintText = ""
    @State private var showCancelDonationConfirm = false
    @State private var showDonationSentAlert = false
    @State private var donationErrorText: String?
    @State private var showDonationClearedAlert = false
    /// Page index for active vis-a-vis photo stack (Thanks, middle-left).
    @State private var thanksPeerCarouselIndex = 0

    private let columns: [GridItem] = [
        GridItem(.fixed(KindeksLayout.tileWidth), spacing: KindeksLayout.gutter),
        GridItem(.fixed(KindeksLayout.tileWidth), spacing: KindeksLayout.gutter)
    ]

    var body: some View {
        ZStack {
            KindeksScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBar
                    Text(kindeksHeadline)
                        .font(KindeksFont.medium(28))
                        .foregroundStyle(Color.white)
                    if appState.selectedTab == .thanks {
                        LazyVGrid(columns: columns, spacing: KindeksLayout.gutter) {
                            thanksTiles
                        }
                    } else {
                        VStack(alignment: .leading, spacing: KindeksLayout.gutter) {
                            donationsGoalsRow
                            LazyVGrid(columns: columns, spacing: KindeksLayout.gutter) {
                                donationsAmountTiles
                            }
                        }
                    }
                }
                .padding(.horizontal, KindeksLayout.marginHorizontal)
                .padding(.top, KindeksLayout.marginTop)
                .padding(.bottom, KindeksLayout.marginBottom)
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
        .sheet(isPresented: $showAmountSheet) {
            DonationsAmountSheet()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showDailySheet) {
            DailyPlaceholderSheet()
        }
        .sheet(isPresented: $showAddGoalSheet) {
            AddDonationGoalSheet()
                .environmentObject(appState)
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: DashboardRoute.self) { route in
            switch route {
            case .aura:
                AuraView()
                    .environmentObject(appState)
            case .nearbySession:
                NearbySessionView(onViewPeerKindeks: onViewPeerKindeks)
                    .environmentObject(appState)
            }
        }
        .onChange(of: appState.donationRecipient?.id) { _, _ in
            appState.selectedDonationGoalId = nil
        }
        .alert("Cancel donation?", isPresented: $showCancelDonationConfirm) {
            Button("Keep editing", role: .cancel) {}
            Button("Clear goal & amount", role: .destructive) {
                appState.cancelDonation()
                showDonationClearedAlert = true
            }
        } message: {
            Text("Your chosen goal and amount will be cleared.")
        }
        .alert("Donation sent", isPresented: $showDonationSentAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your amount was sent in USD ($1 equals $1).")
        }
        .alert("Could not send", isPresented: Binding(
            get: { donationErrorText != nil },
            set: { if !$0 { donationErrorText = nil } }
        )) {
            Button("OK", role: .cancel) { donationErrorText = nil }
        } message: {
            Text(donationErrorText ?? "")
        }
        .alert("Cancelled", isPresented: $showDonationClearedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Goal and amount were cleared.")
        }
        .onChange(of: appState.receivers.count) { _, newCount in
            if newCount == 0 {
                thanksPeerCarouselIndex = 0
            } else if thanksPeerCarouselIndex >= newCount {
                thanksPeerCarouselIndex = max(0, newCount - 1)
            }
        }
    }

    private var kindeksHeadline: String {
        switch context {
        case .own:
            return "My Kindeks"
        case .peer(_, let name, _):
            let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "Kindeks" : "\(t)'s Kindeks"
        }
    }

    private var donationsGoalsRow: some View {
        let items = donationCarouselItems()
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: KindeksLayout.gutter) {
                ForEach(items) { item in
                    donationCarouselPage(item)
                        .frame(width: KindeksLayout.tileWidth, height: KindeksLayout.tileHeight)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: KindeksLayout.tileHeight)
    }

    private func donationCarouselItems() -> [DonationCarouselItem] {
        let goals = appState.donationGoalsForCarousel(context: context)
        var items: [DonationCarouselItem] = goals.map { .goal($0) }
        guard case .own = context else { return items }

        let maxGoals = DonationGoalsLocalStore.maxGoalsPerAccount
        let remainingSlots = maxGoals - goals.count
        guard remainingSlots > 0 else { return items }

        // Пустое состояние: две плитки под фото целей; дальше — одна «Add goal», пока не упёрлись в лимит.
        if goals.isEmpty {
            let addCount = min(2, remainingSlots)
            items.append(contentsOf: (0..<addCount).map { DonationCarouselItem.addOwn(slot: $0) })
        } else {
            items.append(.addOwn(slot: 0))
        }
        return items
    }

    @ViewBuilder
    private func donationCarouselPage(_ item: DonationCarouselItem) -> some View {
        switch item {
        case .goal(let goal):
            Button {
                appState.selectedDonationGoalId = goal.id
            } label: {
                DonationGoalCardContent(
                    goal: goal,
                    isSelected: appState.selectedDonationGoalId == goal.id
                )
            }
            .buttonStyle(KindeksPlainHeaderButtonStyle())
        case .addOwn:
            Button {
                showAddGoalSheet = true
            } label: {
                DonationPlaceholderCardContent(
                    systemImage: "plus.circle.fill",
                    title: "Add goal",
                    subtitle: "Up to \(DonationGoalsLocalStore.maxGoalsPerAccount) on device",
                    style: .frostedLight
                )
            }
            .buttonStyle(KindeksPlainHeaderButtonStyle())
        }
    }

    private var headerBar: some View {
        ZStack {
            KindeksSegmentedTabs(selection: $appState.selectedTab)
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    KindeksHeaderBackMark()
                }
                .buttonStyle(KindeksPlainHeaderButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var thanksTiles: some View {
        // Row 1 — Figma: session timer | owner notifications (incoming thanks / donations)
        KindeksGlassTile(mesh: .timerBlue, action: nil) {
            ThanksTimerGaugeContent(
                minutes: thanksTimerMinutes,
                progress: thanksSessionProgress
            )
        }

        KindeksGlassTile(mesh: .starry, action: { showDailySheet = true }) {
            Color.clear
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
        }

        // Row 2 — Figma: swipeable stack of nearby vis-a-vis | send thanks (“K”)
        thanksActivePeersTile

        KindeksGlassTile(mesh: .brandK, action: handleSendThanksTap) {
            ThanksSendKMarkContent()
        }

        // Row 3 — Figma: Aura | session availability + BLE (opens Nearby / session controls)
        NavigationLink(value: DashboardRoute.aura) {
            KindeksGlassTile(mesh: .sphereGlow, action: nil) {
                KindeksAuraCircleContent(state: appState.auraVisualState)
            }
        }
        .buttonStyle(.plain)

        NavigationLink(value: DashboardRoute.nearbySession) {
            KindeksGlassTile(mesh: .sessionOrange, action: nil) {
                SessionEndsContent(
                    primaryText: sessionEndsDisplay,
                    showUnderline: appState.isAccepting && appState.sessionRemainingSeconds > 0
                )
            }
        }
        .buttonStyle(.plain)
    }

    /// Middle-left Thanks tile: photos of active peers (horizontal swipe) + “N active” badge.
    private var thanksActivePeersTile: some View {
        KindeksGlassTile(mesh: .thanksImage, action: nil, backing: {
            ZStack {
                if appState.receivers.isEmpty {
                    thanksActivePeersEmptyBacking
                } else {
                    TabView(selection: $thanksPeerCarouselIndex) {
                        ForEach(Array(appState.receivers.enumerated()), id: \.element.id) { index, receiver in
                            thanksPeerSlideImage(for: receiver)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                KindeksPalette.overlayDark.opacity(0.2)
            }
        }, content: {
            VStack(spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    Text(activeBadgeText)
                        .font(KindeksFont.regular(11))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial.opacity(0.72))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
                Spacer(minLength: 0)
            }
        })
    }

    @ViewBuilder
    private func thanksPeerSlideImage(for receiver: Receiver) -> some View {
        Group {
            if let data = receiver.avatarData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            KindeksPalette.orange.opacity(0.55),
                            KindeksPalette.deepBlue.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: receiver.icon)
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var thanksActivePeersEmptyBacking: some View {
        Group {
            if let profileAvatarData, let ui = UIImage(data: profileAvatarData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        KindeksPalette.orange.opacity(0.55),
                        KindeksPalette.deepBlue.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var donationsAmountTiles: some View {
        KindeksGlassTile(mesh: .donationMesh, action: {
            appState.selectedDonationAmount = 1
        }) {
            Text("1$")
                .font(KindeksFont.medium(52))
                .foregroundStyle(Color.white)
        }

        KindeksGlassTile(mesh: .blueSum, action: { showAmountSheet = true }) {
            Text("Choose your\nsum")
                .font(KindeksFont.medium(20))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }

        KindeksGlassTile(mesh: .cancelPurple, action: { showCancelDonationConfirm = true }) {
            CancelTileContent()
        }

        KindeksGlassTile(mesh: .sendTeal, isDisabled: !canSendDonation, action: sendDonation) {
            SendTileContent(enabled: canSendDonation)
        }
    }

    /// Whole minutes shown inside the blue pill (Figma-style “36 min”).
    private var thanksTimerMinutes: Int? {
        guard appState.isAccepting, appState.sessionRemainingSeconds > 0 else { return nil }
        return max(1, appState.sessionRemainingSeconds / 60)
    }

    private var thanksSessionProgress: CGFloat {
        let total = CGFloat(45 * 60)
        guard appState.isAccepting, total > 0 else { return 0 }
        return CGFloat(appState.sessionRemainingSeconds) / total
    }

    private var activeBadgeText: String {
        let n = max(appState.receivers.count, 0)
        return "\(n) active"
    }

    private var canSendDonation: Bool {
        guard case .peer = context else { return false }
        return appState.donationRecipient != nil
            && appState.selectedDonationGoalId != nil
            && appState.selectedDonationAmount != nil
    }

    /// Figma: “K” tile — send thanks (same rules as previous double-tap on the photo tile).
    private func handleSendThanksTap() {
        if appState.isAccepting, appState.pendingInvite != nil {
            appState.sendThanks()
            showSuccessBurst()
        } else if appState.isAccepting {
            showHint("Waiting for a nearby donation invite")
        } else {
            showHint("Start session first")
        }
    }

    private func sendDonation() {
        Task { @MainActor in
            let ok = await appState.sendDonationOverBLE()
            if ok {
                showDonationSentAlert = true
            } else {
                donationErrorText = "Could not deliver donation (timeout or connection)."
            }
        }
    }

    private func showHint(_ text: String) {
        nearbyHintText = text
        showNearbyHint = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showNearbyHint = false
        }
    }

    private func showSuccessBurst() {
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showSuccess = false
        }
    }

    private var sessionEndsDisplay: String {
        guard appState.isAccepting else { return "—" }
        let seconds = appState.sessionRemainingSeconds
        if seconds <= 0 { return "0h" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0, minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    private var successOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(KindeksPalette.mint)
            Text("Sent")
                .font(KindeksFont.medium(20))
                .foregroundStyle(Color.white)
        }
        .padding(26)
        .background(.ultraThinMaterial.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var nearbyHintOverlay: some View {
        Text(nearbyHintText)
            .font(KindeksFont.regular(11))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.82))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}

private struct KindeksPlainHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

private enum DashboardRoute: Hashable {
    case aura
    case nearbySession
}

private struct CancelTileContent: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(Color(red: 0.2, green: 0.1, blue: 0.32).opacity(0.88))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(red: 0.42, green: 0.28, blue: 0.52))
            }
            Spacer(minLength: 0)
            Text("CANCEL")
                .font(KindeksFont.regular(11))
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(.bottom, 14)
        }
    }
}

private struct SendTileContent: View {
    let enabled: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Spacer(minLength: 0)
            Text("SEND")
                .font(KindeksFont.regular(11))
                .foregroundStyle(Color.white.opacity(enabled ? 0.95 : 0.45))
                .padding(.bottom, 14)
        }
    }
}

/// Figma middle-right Thanks tile: gradient + circular “K” — send thanks.
private struct ThanksSendKMarkContent: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 72, height: 72)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
            Text("K")
                .font(KindeksFont.medium(34))
                .foregroundStyle(Color.white)
        }
    }
}

/// Figma “timer tile”: faint outer track, bright progress arc (~10:30 → ~7), needle + dot, solid blue center, “36 min” typography.
private struct ThanksTimerGaugeContent: View {
    /// `nil` when session off — shows “—”.
    let minutes: Int?
    let progress: CGFloat

    /// Indicator & arc start (~10:30 on the clock), as `Circle.trim` fraction (0 = top after −90° rotation).
    private var headTrim: CGFloat { 10.5 / 12.0 }
    /// Full arc length in trim space (Figma: dot at 10:30 clockwise to ~7 o’clock).
    private var maxArcSpan: CGFloat { 0.708 }
    private var arcSpan: CGFloat { max(0, progress) * maxArcSpan }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerR = side * 0.36
            let innerR = side * 0.245

            ZStack {
                TimerFaintTrack(radius: outerR)
                    .position(center)

                TimerProgressArc(headTrim: headTrim, arcSpan: arcSpan, radius: outerR)
                    .position(center)

                TimerNeedleAndDot(trimT: headTrim, innerR: innerR, outerR: outerR)
                    .position(center)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.38, green: 0.52, blue: 0.98),
                                Color(red: 0.22, green: 0.38, blue: 0.88),
                                KindeksPalette.blue.opacity(0.95)
                            ],
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 1,
                            endRadius: innerR * 1.05
                        )
                    )
                    .frame(width: innerR * 2, height: innerR * 2)
                    .position(center)
                    .opacity(minutes == nil ? 0.45 : 1)

                Group {
                    if let minutes {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(minutes)")
                                .font(KindeksFont.medium(26))
                            Text("min")
                                .font(KindeksFont.regular(12))
                        }
                        .foregroundStyle(Color.white.opacity(0.94))
                    } else {
                        Text("—")
                            .font(KindeksFont.medium(26))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                }
                .position(center)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct TimerFaintTrack: View {
    let radius: CGFloat

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.13), lineWidth: 1)
            .frame(width: radius * 2, height: radius * 2)
    }
}

private struct TimerProgressArc: View {
    let headTrim: CGFloat
    let arcSpan: CGFloat
    let radius: CGFloat

    var body: some View {
        ZStack {
            let endTrim = headTrim + arcSpan
            if arcSpan <= 0.0001 {
                EmptyView()
            } else if endTrim <= 1.001 {
                Circle()
                    .trim(from: headTrim, to: min(endTrim, 1))
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 1.25, lineCap: .round)
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.white.opacity(0.55), radius: 2, x: 0, y: 0)
            } else {
                Circle()
                    .trim(from: headTrim, to: 1)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 1.25, lineCap: .round)
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.white.opacity(0.55), radius: 2, x: 0, y: 0)
                Circle()
                    .trim(from: 0, to: endTrim - 1)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 1.25, lineCap: .round)
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.white.opacity(0.55), radius: 2, x: 0, y: 0)
            }
        }
    }
}

private struct TimerNeedleAndDot: View {
    let trimT: CGFloat
    let innerR: CGFloat
    let outerR: CGFloat

    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let inner = gaugePoint(center: c, radius: innerR, trimT: trimT)
            let outer = gaugePoint(center: c, radius: outerR, trimT: trimT)

            var needle = Path()
            needle.move(to: inner)
            needle.addLine(to: outer)
            context.stroke(needle, with: .color(.white.opacity(0.95)), lineWidth: 0.85)

            let dotR: CGFloat = 2.2
            let dotRect = CGRect(x: outer.x - dotR, y: outer.y - dotR, width: dotR * 2, height: dotR * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(.white))
        }
        .frame(width: outerR * 2 + 4, height: outerR * 2 + 4)
        .allowsHitTesting(false)
    }

    /// `trimT` = 0 at top, increases clockwise (matches `Circle.trim` after −90°).
    private func gaugePoint(center: CGPoint, radius: CGFloat, trimT: CGFloat) -> CGPoint {
        let a = 2 * CGFloat.pi * trimT
        return CGPoint(
            x: center.x + radius * sin(a),
            y: center.y - radius * cos(a)
        )
    }
}

/// Превью ауры на плитке K (без цифр).
private struct KindeksAuraCircleContent: View {
    let state: AuraVisualState

    var body: some View {
        AuraOrbView(state: state, diameter: 76)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
    }
}

/// Стрелка «назад» в духе макета: вертикальный штрих + chevron (K-образный силуэт).
private struct KindeksHeaderBackMark: View {
    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.white)
                .frame(width: 2.5, height: 14)
            Image(systemName: "chevron.left")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.white)
                .offset(x: -3)
        }
        .frame(minWidth: 28, minHeight: 24, alignment: .leading)
    }
}

private struct SessionEndsContent: View {
    let primaryText: String
    let showUnderline: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Text("Session ends")
                    .font(KindeksFont.regular(11))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.38))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            Spacer(minLength: 0)
            VStack(spacing: 5) {
                SessionEndsStripedTimeText(text: primaryText)
                if showUnderline {
                    Capsule()
                        .fill(KindeksPalette.sky)
                        .frame(width: underlineWidth, height: 2)
                }
            }
            .padding(.bottom, 12)
        }
    }

    /// Грубая оценка ширины подчёркивания под числом времени.
    private var underlineWidth: CGFloat {
        min(24 + CGFloat(primaryText.count) * 22, 160)
    }
}

/// Крупное время с диагональной «шахматной» заливкой, как в Figma.
private struct SessionEndsStripedTimeText: View {
    let text: String

    var body: some View {
        SessionEndsDiagonalHatch()
            .frame(width: 240, height: 76)
            .mask(
                Text(text)
                    .font(KindeksFont.medium(52))
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)
                    .frame(width: 220)
            )
    }
}

private struct SessionEndsDiagonalHatch: View {
    var body: some View {
        Canvas { context, size in
            let cw = size.width
            let ch = size.height
            context.translateBy(x: cw / 2, y: ch / 2)
            context.rotate(by: .degrees(-52))
            context.translateBy(x: -cw / 2, y: -ch / 2)
            let warmLight = Color(red: 0.91, green: 0.65, blue: 0.38)
            let warmDark = Color(red: 0.58, green: 0.34, blue: 0.24)
            var y: CGFloat = -ch * 1.2
            var i = 0
            while y < ch * 2.2 {
                var path = Path()
                path.move(to: CGPoint(x: -cw, y: y))
                path.addLine(to: CGPoint(x: cw * 2.5, y: y))
                let color = i % 2 == 0 ? warmLight : warmDark
                context.stroke(path, with: .color(color), lineWidth: 2.6)
                y += 4.4
                i += 1
            }
        }
        .allowsHitTesting(false)
    }
}

private struct NearbySessionView: View {
    @EnvironmentObject private var appState: AppState

    var onViewPeerKindeks: ((Receiver) -> Void)? = nil

    private var sessionStatusText: String {
        if appState.isAccepting {
            let mins = max(1, appState.sessionRemainingSeconds / 60)
            return "Session active · ends in \(mins)m"
        }
        return "Session off"
    }

    var body: some View {
        ZStack {
            KindeksScreenBackground()
            VStack(spacing: 14) {
                Toggle(isOn: Binding(
                    get: { appState.isAccepting },
                    set: { newValue in
                        if appState.isAccepting != newValue {
                            appState.toggleAccepting()
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("45-min session")
                            .font(KindeksFont.medium(18))
                            .foregroundStyle(Color.white)
                        Text(sessionStatusText)
                            .font(KindeksFont.regular(12))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                }
                .tint(KindeksPalette.mint)
                .padding(14)
                .background(.ultraThinMaterial.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

                if appState.receivers.isEmpty {
                    VStack(spacing: 6) {
                        Text(appState.isAccepting ? "Searching nearby users..." : "Start session to search nearby users")
                            .font(KindeksFont.regular(13))
                            .foregroundStyle(Color.white.opacity(0.76))
                    }
                    .frame(maxWidth: .infinity, minHeight: 90)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    List(appState.receivers) { receiver in
                        Button {
                            appState.selectedReceiver = receiver
                        } label: {
                            HStack(spacing: 12) {
                                avatar(for: receiver)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(receiver.name)
                                        .foregroundStyle(.white.opacity(0.94))
                                    if appState.selectedReceiver == receiver {
                                        Text("Selected")
                                            .font(KindeksFont.regular(11))
                                            .foregroundStyle(KindeksPalette.mint)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if let onViewPeerKindeks {
                                Button {
                                    onViewPeerKindeks(receiver)
                                } label: {
                                    Text("Kindeks")
                                }
                                .tint(Color(red: 0.42, green: 0.35, blue: 0.75))
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listStyle(.plain)
                }
            }
            .padding(.horizontal, KindeksLayout.marginHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .navigationTitle("Nearby")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func avatar(for receiver: Receiver) -> some View {
        if let data = receiver.avatarData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        } else {
            Image(systemName: receiver.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
        }
    }
}

private struct DailyPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                KindeksMeshBackground(style: .starry)
                    .ignoresSafeArea()
                KindeksPalette.background.opacity(0.35)
                    .ignoresSafeArea()
                VStack(spacing: 18) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Text("Starry thanks")
                        .font(KindeksFont.medium(24))
                        .foregroundStyle(Color.white)
                    Text("Fullscreen daily mode — coming soon.")
                        .font(KindeksFont.regular(14))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .toolbarBackground(.clear, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

private enum DonationPlaceholderStyle {
    case frostedLight
    case donationMesh
}

private struct DonationGoalCardContent: View {
    let goal: DonationGoal
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.42))
            Group {
                if let data = goal.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    KindeksMeshBackground(style: .donationMesh)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous))
            .opacity(0.92)

            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(goal.title)
                    .font(KindeksFont.medium(20))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                if !goal.subtitle.isEmpty {
                    Text(goal.subtitle)
                        .font(KindeksFont.regular(13))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
        }
        .frame(width: KindeksLayout.tileWidth, height: KindeksLayout.tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous)
                .stroke(isSelected ? KindeksPalette.mint : Color.white.opacity(0.2), lineWidth: isSelected ? 2.5 : 1)
        )
    }
}

private struct DonationPlaceholderCardContent: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let style: DonationPlaceholderStyle

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.35))
            Group {
                switch style {
                case .frostedLight:
                    KindeksMeshBackground(style: .frostedLight)
                case .donationMesh:
                    KindeksMeshBackground(style: .donationMesh)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous))
            .opacity(0.88)

            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text(title)
                    .font(KindeksFont.medium(18))
                    .foregroundStyle(Color.white)
                Text(subtitle)
                    .font(KindeksFont.regular(12))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(12)
        }
        .frame(width: KindeksLayout.tileWidth, height: KindeksLayout.tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }
}
