import SwiftUI

struct ReceiverPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List(appState.receivers) { receiver in
                Button {
                    appState.selectedReceiver = receiver
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: receiver.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                        Text(receiver.name)
                            .foregroundStyle(.white.opacity(0.94))
                        Spacer()
                        if appState.selectedReceiver == receiver {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Choose receiver")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            appState.startBLEScanning()
        }
        .onDisappear {
            appState.stopBLEScanning()
        }
        .preferredColorScheme(.dark)
    }
}
