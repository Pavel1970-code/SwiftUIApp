import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        NavigationStack {
            DashboardView()
                .environmentObject(appState)
        }
    }
}

#Preview {
    ContentView()
}
