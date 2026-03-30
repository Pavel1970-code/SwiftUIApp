import SwiftUI

struct AuraView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section("History") {
                if appState.history.isEmpty {
                    Text("No activity yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedEvents) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(eventTitle(event))
                                .font(.headline)
                            if let receiverLabel = event.receiverLabel {
                                Text(receiverLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let amount = event.amount, event.type == .donation {
                                Text("$\(amount)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(event.timestamp, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Partners") {
                Text("Partners placeholder")
                    .foregroundStyle(.secondary)
            }

            Section("Silence") {
                Toggle("Silence mode", isOn: $appState.silenceMode)
            }

            Section("Widget") {
                Text("Widget placeholder")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Your Aura")
    }

    private var sortedEvents: [HistoryEvent] {
        appState.history.sorted(by: { $0.timestamp > $1.timestamp })
    }

    private func eventTitle(_ event: HistoryEvent) -> String {
        switch (event.type, event.direction) {
        case (.thanks, .sent):
            return "Sent Thanks"
        case (.thanks, .received):
            return "Received Thanks"
        case (.donation, .sent):
            return "Sent Donation"
        case (.donation, .received):
            return "Received Donation"
        }
    }
}
