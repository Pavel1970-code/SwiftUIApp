import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List(sortedEvents) { event in
            VStack(alignment: .leading, spacing: 5) {
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("History")
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
