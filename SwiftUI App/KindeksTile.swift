import SwiftUI

private struct KindeksPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

enum KindeksMeshStyle: Equatable {
    case frostedLight
    case donationMesh
    case blueSum
    case cancelPurple
    case sendTeal
    case timerBlue
    case starry
    case thanksImage
    case brandK
    case sphereGlow
    case sessionOrange
}

struct KindeksMeshBackground: View {
    let style: KindeksMeshStyle

    var body: some View {
        ZStack {
            baseFill
            meshRadials
        }
        .blur(radius: meshBlurRadius)
    }

    private var meshBlurRadius: CGFloat {
        switch style {
        case .frostedLight: return 0
        case .timerBlue: return 7
        case .sendTeal: return 5
        default: return 12
        }
    }

    @ViewBuilder
    private var baseFill: some View {
        switch style {
        case .frostedLight:
            LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.9, blue: 0.92),
                    Color(red: 0.8, green: 0.8, blue: 0.84)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .donationMesh:
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.9, blue: 0.82),
                    Color(red: 0.78, green: 0.74, blue: 0.94),
                    Color(red: 0.65, green: 0.72, blue: 0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .blueSum:
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.38, blue: 0.78),
                    Color(red: 0.1, green: 0.22, blue: 0.52),
                    Color(red: 0.04, green: 0.1, blue: 0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .cancelPurple:
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.12, blue: 0.45), KindeksPalette.purple],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        case .sendTeal:
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.32, blue: 0.34),
                    Color(red: 0.05, green: 0.22, blue: 0.24),
                    Color(red: 0.04, green: 0.16, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .timerBlue:
            LinearGradient(
                colors: [
                    Color(red: 0.54, green: 0.60, blue: 0.70).opacity(0.42),
                    Color(red: 0.34, green: 0.40, blue: 0.50).opacity(0.55),
                    Color(red: 0.14, green: 0.18, blue: 0.26).opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .starry:
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.14),
                    Color(red: 0.1, green: 0.06, blue: 0.22),
                    Color.black
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        case .thanksImage:
            LinearGradient(
                colors: [KindeksPalette.orange.opacity(0.55), KindeksPalette.deepBlue.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .brandK:
            LinearGradient(
                colors: [KindeksPalette.peach.opacity(0.9), KindeksPalette.mint.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sphereGlow:
            LinearGradient(
                colors: [KindeksPalette.deepBlue, KindeksPalette.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sessionOrange:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.38, green: 0.16, blue: 0.22),
                        Color(red: 0.08, green: 0.06, blue: 0.18)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.62, blue: 0.12).opacity(0.88),
                        Color(red: 0.95, green: 0.45, blue: 0.1).opacity(0.35),
                        .clear
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .init(x: 0.55, y: 0.45)
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.12, green: 0.08, blue: 0.28).opacity(0.92),
                        Color(red: 0.18, green: 0.1, blue: 0.32).opacity(0.55),
                        .clear
                    ],
                    center: .init(x: 0.78, y: 0.78),
                    startRadius: 24,
                    endRadius: 150
                )
            }
        }
    }

    @ViewBuilder
    private var meshRadials: some View {
        switch style {
        case .frostedLight:
            EmptyView()
        case .donationMesh:
            ZStack {
                RadialGradient(
                    colors: [Color.white.opacity(0.35), .clear],
                    center: .init(x: 0.25, y: 0.2),
                    startRadius: 6,
                    endRadius: 90
                )
                RadialGradient(
                    colors: [KindeksPalette.sky.opacity(0.25), .clear],
                    center: .init(x: 0.88, y: 0.75),
                    startRadius: 8,
                    endRadius: 85
                )
            }
        case .blueSum:
            RadialGradient(
                colors: [Color.white.opacity(0.35), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 140
            )
        case .cancelPurple:
            RadialGradient(
                colors: [KindeksPalette.purple.opacity(0.55), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 95
            )
        case .sendTeal:
            ZStack {
                SendTileVerticalRibs()
                RadialGradient(
                    colors: [KindeksPalette.sky.opacity(0.22), .clear],
                    center: .init(x: 0.35, y: 0.15),
                    startRadius: 6,
                    endRadius: 88
                )
            }
        case .timerBlue:
            RadialGradient(
                colors: [
                    Color(red: 0.42, green: 0.82, blue: 0.88).opacity(0.22),
                    Color(red: 0.35, green: 0.55, blue: 0.75).opacity(0.08),
                    .clear
                ],
                center: .init(x: 0.9, y: 0.06),
                startRadius: 6,
                endRadius: 110
            )
        case .starry:
            StarrySpeckles()
        case .thanksImage:
            RadialGradient(
                colors: [KindeksPalette.orange.opacity(0.4), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 100
            )
        case .brandK:
            RadialGradient(
                colors: [KindeksPalette.aquaSoft.opacity(0.5), .clear],
                center: .bottomTrailing,
                startRadius: 12,
                endRadius: 105
            )
        case .sphereGlow:
            ZStack {
                RadialGradient(
                    colors: [
                        Color(red: 0.45, green: 0.22, blue: 0.62).opacity(0.55),
                        Color(red: 0.18, green: 0.1, blue: 0.35).opacity(0.35),
                        .clear
                    ],
                    center: .center,
                    startRadius: 6,
                    endRadius: 58
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.45),
                        Color(red: 0.55, green: 0.3, blue: 0.85).opacity(0.2),
                        .clear
                    ],
                    center: .init(x: 0.42, y: 0.48),
                    startRadius: 4,
                    endRadius: 38
                )
                RadialGradient(
                    colors: [KindeksPalette.sky.opacity(0.2), .clear],
                    center: .init(x: 0.2, y: 0.78),
                    startRadius: 4,
                    endRadius: 72
                )
            }
        case .sessionOrange:
            ZStack {
                RadialGradient(
                    colors: [
                        Color(red: 0.52, green: 0.28, blue: 0.35).opacity(0.55),
                        .clear
                    ],
                    center: .init(x: 0.88, y: 0.12),
                    startRadius: 8,
                    endRadius: 88
                )
                RadialGradient(
                    colors: [
                        KindeksPalette.purple.opacity(0.35),
                        .clear
                    ],
                    center: .init(x: 0.55, y: 0.65),
                    startRadius: 16,
                    endRadius: 100
                )
            }
        }
    }
}

private struct SendTileVerticalRibs: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 4.5
            var x: CGFloat = -step
            var i = 0
            while x < size.width + step * 2 {
                let stripe = (i % 2 == 0)
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                let op = stripe ? 0.14 : 0.05
                context.stroke(path, with: .color(Color.white.opacity(op)), lineWidth: stripe ? 1.4 : 0.9)
                x += step
                i += 1
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StarrySpeckles: View {
    var body: some View {
        Canvas { context, size in
            let count = 52
            for i in 0..<count {
                let u = CGFloat((i * 47) % 97) / 97
                let v = CGFloat((i * 31) % 89) / 89
                let x = u * size.width
                let y = v * size.height
                let r = CGFloat(0.5 + Double(i % 4) * 0.45)
                let rect = CGRect(x: x, y: y, width: r, height: r)
                let warm = (i % 7 < 2)
                let color: Color = warm
                    ? Color(red: 1, green: 0.72, blue: 0.38).opacity(0.35 + Double(i % 4) * 0.08)
                    : Color(red: 0.75, green: 0.88, blue: 1).opacity(0.12 + Double(i % 5) * 0.07)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .allowsHitTesting(false)
    }
}

struct KindeksGlassTile<Backing: View, Content: View>: View {
    let mesh: KindeksMeshStyle
    var isDisabled: Bool = false
    var action: (() -> Void)? = nil
    @ViewBuilder var backing: () -> Backing
    @ViewBuilder var content: () -> Content

    init(
        mesh: KindeksMeshStyle,
        isDisabled: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder backing: @escaping () -> Backing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.mesh = mesh
        self.isDisabled = isDisabled
        self.action = action
        self.backing = backing
        self.content = content
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    tileBody
                }
                .buttonStyle(KindeksPlainButtonStyle())
                .disabled(isDisabled)
            } else {
                tileBody
            }
        }
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var glassMaterialOpacity: Double {
        switch mesh {
        case .frostedLight: return 0.38
        case .starry: return 0.52
        case .thanksImage: return 0.62
        default: return 0.72
        }
    }

    private var tileBody: some View {
        ZStack {
            KindeksMeshBackground(style: mesh)
            backing()
            KindeksPalette.overlayLight.opacity(mesh == .frostedLight ? 0.1 : 0.14)
            KindeksPalette.overlayDark.opacity(mesh == .frostedLight ? 0.08 : 0.16)
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(glassMaterialOpacity)
            content()
        }
        .frame(width: KindeksLayout.tileWidth, height: KindeksLayout.tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: KindeksLayout.cornerRadius, style: .continuous))
    }
}

extension KindeksGlassTile where Backing == EmptyView {
    init(
        mesh: KindeksMeshStyle,
        isDisabled: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(mesh: mesh, isDisabled: isDisabled, action: action, backing: { EmptyView() }, content: content)
    }
}

struct KindeksSegmentedTabs: View {
    @Binding var selection: DashboardTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.segmentOrder) { tab in
                let isOn = selection == tab
                Text(tab.rawValue)
                    .font(KindeksFont.regular(14))
                    .foregroundStyle(Color.white.opacity(isOn ? 0.98 : 0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if isOn {
                            Capsule()
                                .fill(Color.white.opacity(0.22))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        selection = tab
                    }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .frame(width: 220)
    }
}
