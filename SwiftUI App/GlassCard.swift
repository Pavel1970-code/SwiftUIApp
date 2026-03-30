import SwiftUI

/// Press feedback without `DragGesture`, which often fights `Button` + `ScrollView` and blocks taps (especially on Simulator).
private struct GlassCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct GlassCard<Content: View>: View {
    let action: (() -> Void)?
    let isDisabled: Bool
    @ViewBuilder var content: Content

    init(action: (() -> Void)? = nil, isDisabled: Bool = false, @ViewBuilder content: () -> Content) {
        self.action = action
        self.isDisabled = isDisabled
        self.content = content()
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    cardContent
                        // Full-tile hit testing (blur/material often shrinks the tappable area).
                        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
                .buttonStyle(GlassCardButtonStyle())
                .disabled(isDisabled)
            } else {
                cardContent
            }
        }
        .opacity(isDisabled ? 0.55 : 1)
    }

    private var cardContent: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 10)
    }
}
