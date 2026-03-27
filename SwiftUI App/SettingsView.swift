import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Toggle("Silence mode", isOn: $appState.silenceMode)
        }
        .navigationTitle("Settings")
    }
}
