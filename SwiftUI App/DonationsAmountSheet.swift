import SwiftUI

struct DonationsAmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var amount: Double = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 26) {
                Text(amountText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Slider(value: $amount, in: 1...50, step: 1)
                    .tint(.white)

                Text("Mock amount selector")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                Button("Confirm") {
                    appState.selectedGiftId = nil
                    appState.selectedDonationAmount = Int(amount)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.85))
                .foregroundStyle(.black)

                Spacer()
            }
            .padding(24)
            .background(Color.black)
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
        .preferredColorScheme(.dark)
    }

    private var amountText: String {
        String(format: "$%.0f", amount)
    }
}
