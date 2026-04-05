import SwiftUI

struct AuraView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section {
                if appState.history.isEmpty {
                    Text("No activity yet")
                        .font(KindeksFont.regular(14))
                        .foregroundStyle(.white.opacity(0.55))
                        .listRowBackground(KindeksAuraRowBackground())
                } else {
                    ForEach(sortedEvents) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(eventTitle(event))
                                .font(KindeksFont.medium(16))
                                .foregroundStyle(.white)
                            if let receiverLabel = event.receiverLabel {
                                Text(receiverLabel)
                                    .font(KindeksFont.regular(13))
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                            if let amount = event.amount, event.type == .donation {
                                Text("$\(amount)")
                                    .font(KindeksFont.regular(13))
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                            Text(event.timestamp, format: .dateTime.hour().minute())
                                .font(KindeksFont.regular(11))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(KindeksAuraRowBackground())
                    }
                }
            } header: {
                sectionHeader("History")
            }

            Section {
                Text("Partners placeholder")
                    .font(KindeksFont.regular(14))
                    .foregroundStyle(.white.opacity(0.55))
                    .listRowBackground(KindeksAuraRowBackground())
            } header: {
                sectionHeader("Partners")
            }

            Section {
                Toggle("Silence mode", isOn: $appState.silenceMode)
                    .font(KindeksFont.regular(15))
                    .foregroundStyle(.white)
                    .tint(KindeksPalette.mint)
                    .listRowBackground(KindeksAuraRowBackground())
            } header: {
                sectionHeader("Silence")
            }

            Section {
                Text("Widget placeholder")
                    .font(KindeksFont.regular(14))
                    .foregroundStyle(.white.opacity(0.55))
                    .listRowBackground(KindeksAuraRowBackground())
            } header: {
                sectionHeader("Widget")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(KindeksPalette.background)
        .navigationTitle("Your Aura")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(KindeksPalette.background, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(KindeksFont.regular(11))
            .foregroundStyle(.white.opacity(0.48))
            .textCase(.uppercase)
            .padding(.top, 8)
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

private struct KindeksAuraRowBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: KindeksLayout.fieldCornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.07))
    }
}
