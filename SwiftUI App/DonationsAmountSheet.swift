import SwiftUI

struct DonationsAmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var amount: Double = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 26) {
                Text(amountText)
                    .font(KindeksFont.medium(44))
                    .foregroundStyle(.white)

                Slider(value: $amount, in: 1...50, step: 1)
                    .tint(KindeksPalette.sky)

                Text("$1 on the slider is one US dollar.")
                    .font(KindeksFont.regular(11))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)

                Button("Confirm") {
                    appState.selectedDonationAmount = Int(amount)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.88))
                .foregroundStyle(.black)

                Spacer()
            }
            .padding(24)
            .background(KindeksPalette.background)
            .navigationTitle("Choose your sum")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            amount = Double(appState.selectedDonationAmount ?? 1)
        }
        .toolbarBackground(KindeksPalette.background, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var amountText: String {
        String(format: "$%.0f", amount)
    }
}
