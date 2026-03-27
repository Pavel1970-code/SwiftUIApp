import SwiftUI

struct DonationsAmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 26) {
                Text(amountText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Slider(value: $appState.selectedDonationAmount, in: 1...50, step: 1)
                    .tint(.white)

                Text("Mock amount selector")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()
            }
            .padding(24)
            .background(Color.black)
            .navigationTitle("Choose your sum")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var amountText: String {
        String(format: "$%.0f", appState.selectedDonationAmount)
    }
}
