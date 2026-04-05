import SwiftUI
import UIKit

/// Base `#090909` + свечение: Donations — бирюза сверху слева к чёрному; Thanks — мягкие акценты сверху.
struct KindeksScreenBackground: View {
    var body: some View {
        ZStack {
            KindeksPalette.background
            RadialGradient(
                colors: [
                    Color(red: 0.12, green: 0.52, blue: 0.56).opacity(0.42),
                    Color(red: 0.06, green: 0.22, blue: 0.26).opacity(0.14),
                    .clear
                ],
                center: UnitPoint(x: 0.08, y: 0.1),
                startRadius: 8,
                endRadius: 340
            )
            .blendMode(.screen)
            RadialGradient(
                colors: [
                    Color(red: 0.2, green: 0.48, blue: 0.54).opacity(0.16),
                    .clear
                ],
                center: UnitPoint(x: 0.52, y: 0.03),
                startRadius: 4,
                endRadius: 220
            )
            .blendMode(.screen)
            RadialGradient(
                colors: [
                    Color(red: 0.26, green: 0.58, blue: 0.62).opacity(0.18),
                    Color(red: 0.15, green: 0.35, blue: 0.42).opacity(0.06),
                    .clear
                ],
                center: UnitPoint(x: 0.9, y: 0.06),
                startRadius: 10,
                endRadius: 280
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

enum KindeksLayout {
    static let designWidth: CGFloat = 375
    static let marginTop: CGFloat = 30
    static let marginBottom: CGFloat = 17
    static let marginHorizontal: CGFloat = 15
    static let gutter: CGFloat = 10
    static let tileWidth: CGFloat = 167
    static let tileHeight: CGFloat = 196
    static let cornerRadius: CGFloat = 26
    /// Поля ввода и вторичные карточки (не плитки сетки).
    static let fieldCornerRadius: CGFloat = 14
}

enum KindeksPalette {
    static let background = Color(red: 9 / 255, green: 9 / 255, blue: 9 / 255)
    static let blue = Color(red: 0x4A / 255, green: 0x6C / 255, blue: 0xF7 / 255)
    static let mint = Color(red: 0x6B / 255, green: 0xC1 / 255, blue: 0xA3 / 255)
    static let purple = Color(red: 0x6A / 255, green: 0x5A / 255, blue: 0xCD / 255)
    static let peach = Color(red: 0xE5 / 255, green: 0x9A / 255, blue: 0x8D / 255)
    static let aquaSoft = Color(red: 0xAE / 255, green: 0xE9 / 255, blue: 0xD1 / 255)
    static let deepBlue = Color(red: 0x00 / 255, green: 0x3C / 255, blue: 0x69 / 255)
    static let sky = Color(red: 0x94 / 255, green: 0xD3 / 255, blue: 0xF4 / 255)
    static let orange = Color(red: 0xFC / 255, green: 0x3C / 255, blue: 0x08 / 255)
    static let overlayLight = Color.white
    static let overlayDark = Color.black
}

enum KindeksFont {
    private static func hasGilroyMedium() -> Bool {
        UIFont(name: "Gilroy-Medium", size: 12) != nil
    }

    private static func hasGilroyRegular() -> Bool {
        UIFont(name: "Gilroy-Regular", size: 12) != nil
    }

    static func medium(_ size: CGFloat) -> Font {
        if hasGilroyMedium() { return .custom("Gilroy-Medium", size: size) }
        return .system(size: size, weight: .medium)
    }

    static func regular(_ size: CGFloat) -> Font {
        if hasGilroyRegular() { return .custom("Gilroy-Regular", size: size) }
        return .system(size: size, weight: .regular)
    }
}
