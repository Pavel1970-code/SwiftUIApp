import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var profileStore = LocalProfileStore()
    @State private var kindeksPath = NavigationPath()

    var body: some View {
        Group {
            if profileStore.profile == nil {
                ProfileOnboardingView(profileStore: profileStore)
            } else {
                NavigationStack(path: $kindeksPath) {
                    DashboardView(
                        context: .own,
                        profileAvatarData: profileStore.profile?.avatarData,
                        onViewPeerKindeks: { receiver in
                            kindeksPath.append(PeerKindeksDestination(receiver: receiver))
                        }
                    )
                    .environmentObject(appState)
                    .onChange(of: kindeksPath.count) { _, newCount in
                        if newCount == 0 {
                            appState.clearDonationRecipient()
                        }
                    }
                    .navigationDestination(for: PeerKindeksDestination.self) { dest in
                        DashboardView(
                            context: .peer(id: dest.id, displayName: dest.displayName, avatarData: dest.avatarData),
                            profileAvatarData: dest.avatarData,
                            onViewPeerKindeks: { receiver in
                                kindeksPath.append(PeerKindeksDestination(receiver: receiver))
                            }
                        )
                        .environmentObject(appState)
                        .task(id: dest.id) {
                            appState.syncDonationRecipient(with: dest)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

private struct LocalProfile: Codable {
    let id: UUID
    let displayName: String
    let avatarData: Data?
    let createdAt: Date
}

@MainActor
private final class LocalProfileStore: ObservableObject {
    @Published private(set) var profile: LocalProfile?
    private let key = "local_profile_v1"

    init() {
        load()
    }

    func createProfile(displayName: String, avatarData: Data?) {
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        profile = LocalProfile(
            id: UUID(),
            displayName: cleanName,
            avatarData: avatarData,
            createdAt: Date()
        )
        persist()
    }

    func resetProfile() {
        profile = nil
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode(LocalProfile.self, from: data) {
            profile = decoded
        }
    }

    private func persist() {
        guard let profile else { return }
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

private struct ProfileOnboardingView: View {
    @ObservedObject var profileStore: LocalProfileStore
    @State private var nickname = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarData: Data?
    @State private var isLoadingAvatar = false

    var body: some View {
        ZStack {
            KindeksScreenBackground()

            VStack(spacing: 20) {
                Text("Create your local profile")
                    .font(KindeksFont.medium(28))
                    .foregroundStyle(.white)

                Text("Stored only on this phone. No registration required.")
                    .font(KindeksFont.regular(14))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    avatarView
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    guard let item = newItem else { return }
                    Task { await loadAvatar(from: item) }
                }

                TextField("Nickname", text: $nickname)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: KindeksLayout.fieldCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: KindeksLayout.fieldCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)

                Button("Continue") {
                    profileStore.createProfile(
                        displayName: nickname,
                        avatarData: avatarData
                    )
                }
                .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 108, height: 108)

            if let avatarData, let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 108, height: 108)
                    .clipShape(Circle())
            } else if isLoadingAvatar {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    private func loadAvatar(from item: PhotosPickerItem) async {
        isLoadingAvatar = true
        defer { isLoadingAvatar = false }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data),
           let compressed = image.jpegData(compressionQuality: 0.82) {
            avatarData = compressed
        }
    }
}
