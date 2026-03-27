import SwiftUI

struct PartnersView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 42))
            Text("Partners")
                .font(.title2.weight(.semibold))
            Text("Placeholder partner content for the prototype.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Partners")
    }
}
