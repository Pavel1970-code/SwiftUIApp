import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let context: KindeksDashboardContext
    let profileAvatarData: Data?
    /// Open a peer’s Kindeks (same grid) from the receiver list.
    var onViewPeerKindeks: ((Receiver) -> Void)? = nil

    @State private var showReceiverSheet = false
    @State private var showAmountSheet = false
    @State private var showDailySheet = false
    @State private var showSuccess = false
    @State private var showNearbyHint = false
    @State private var nearbyHintText = ""

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
                    LazyVGrid(columns: columns, spacing: KindeksLayout.gutter) {
                        if appState.selectedTab == .thanks {
                            thanksTiles
                        } else {
                            donationsTiles
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
        .sheet(isPresented: $showReceiverSheet) {
            ReceiverPickerSheet(onViewPeerKindeks: onViewPeerKindeks)
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

    private var kindeksHeadline: String {
        switch context {
        case .own:
            return "My Kindeks"
        case .peer(let name, _):
            let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "Kindeks" : "\(t)'s Kindeks"
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
        KindeksGlassTile(mesh: .timerBlue, action: appState.toggleAccepting) {
            ThanksTimerGaugeContent(
                minutes: thanksTimerMinutes,
                progress: thanksSessionProgress
            )
        }

        KindeksGlassTile(mesh: .starry, action: { showDailySheet = true }) {
            Color.clear
        }

        // Middle-left (under timer): nearby / active peers — порядок как в обновлённом прототипе Figma.
        KindeksGlassTile(mesh: .sphereGlow, action: { showReceiverSheet = true }) {
            NearbyPeersTileContent(
                nearbyState: appState.nearbyState,
                peerCount: appState.receivers.count,
                sessionActive: appState.isAccepting
            )
        }

        NavigationLink(value: DashboardRoute.aura) {
            KindeksGlassTile(mesh: .brandK, action: nil) {
                KindeksAuraCircleContent()
            }
        }
        .buttonStyle(.plain)

        KindeksGlassTile(mesh: .thanksImage, action: handleDoubleTap, backing: {
            ZStack {
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

        KindeksGlassTile(mesh: .sessionOrange, action: nil) {
            SessionEndsContent(
                primaryText: sessionEndsDisplay,
                showUnderline: appState.isAccepting && appState.sessionRemainingSeconds > 0
            )
        }
    }

    @ViewBuilder
    private var donationsTiles: some View {
        KindeksGlassTile(mesh: .frostedLight, action: {
            appState.selectedGiftId = 0
            appState.selectedDonationAmount = nil
            showReceiverSheet = true
        }) {
            PlusCenterContent()
        }

        KindeksGlassTile(mesh: .frostedLight, action: {
            appState.selectedGiftId = 1
            appState.selectedDonationAmount = nil
            showReceiverSheet = true
        }) {
            PlusCenterContent()
        }

        KindeksGlassTile(mesh: .donationMesh, action: {
            appState.selectedGiftId = nil
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

        KindeksGlassTile(mesh: .cancelPurple, action: appState.cancelDonation) {
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
        let total = CGFloat(2 * 60 * 60)
        guard appState.isAccepting, total > 0 else { return 0 }
        return CGFloat(appState.sessionRemainingSeconds) / total
    }

    private var activeBadgeText: String {
        let n = max(appState.receivers.count, 0)
        return "\(n) active"
    }

    private var canSendDonation: Bool {
        guard appState.selectedReceiver != nil else { return false }
        return appState.selectedGiftId != nil || appState.selectedDonationAmount != nil
    }

    private func handleDoubleTap() {
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
                showSuccessBurst()
            } else {
                showHint("Could not deliver donation (timeout)")
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
}

private struct PlusCenterContent: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.94))
                .frame(width: 56, height: 56)
                .shadow(color: Color.black.opacity(0.14), radius: 5, x: 0, y: 3)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(white: 0.48))
        }
    }
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

/// Плитка Aura: полупрозрачный голубой круг без марки (логотип из Figma позже; цвет плитки — от ауры, отдельно).
private struct KindeksAuraCircleContent: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            KindeksPalette.sky.opacity(0.55),
                            KindeksPalette.mint.opacity(0.38),
                            KindeksPalette.sky.opacity(0.22)
                        ],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 2,
                        endRadius: 44
                    )
                )
            Circle()
                .fill(.ultraThinMaterial.opacity(0.38))
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.32), lineWidth: 1)
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

/// Figma-style orb tile, plus product affordance: open BLE peer list (not in the static mock).
private struct NearbyPeersTileContent: View {
    let nearbyState: NearbyState
    let peerCount: Int
    let sessionActive: Bool

    private var caption: String {
        if !sessionActive {
            return "Session off · tap opens list"
        }
        switch nearbyState {
        case .idle:
            return "Tap to see who’s around"
        case .searching:
            return "Searching…"
        case .found:
            return peerCount == 1 ? "1 person nearby" : "\(peerCount) nearby"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.55, green: 0.38, blue: 0.95),
                            Color(red: 0.25, green: 0.45, blue: 0.92),
                            Color(red: 0.35, green: 0.2, blue: 0.48),
                            .clear
                        ],
                        center: .init(x: 0.42, y: 0.45),
                        startRadius: 4,
                        endRadius: 48
                    )
                )
                .frame(width: 88, height: 88)
                .blur(radius: 3)
                .offset(y: 6)

            VStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text("Nearby")
                    .font(KindeksFont.medium(20))
                    .foregroundStyle(Color.white)
                Text(caption)
                    .font(KindeksFont.regular(11))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
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

private struct DailyPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                KindeksScreenBackground()
                VStack(spacing: 14) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(KindeksPalette.orange.opacity(0.95))
                    Text("Daily mode (coming soon)")
                        .font(KindeksFont.medium(20))
                        .foregroundStyle(Color.white)
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
