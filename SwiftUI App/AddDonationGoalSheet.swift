import PhotosUI
import SwiftUI
import UIKit

struct AddDonationGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var title = ""
    @State private var subtitle = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isLoadingAvatar = false
    @State private var showLimitAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                KindeksPalette.background.ignoresSafeArea()
                VStack(spacing: 18) {
                    Text("Up to \(DonationGoalsLocalStore.maxGoalsPerAccount) goals on this phone.")
                        .font(KindeksFont.regular(12))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        goalImagePickerContent
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        guard let item = newItem else { return }
                        Task { await loadImage(from: item) }
                    }

                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: KindeksLayout.fieldCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: KindeksLayout.fieldCornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .foregroundStyle(.white)

                    TextField("Subtitle (optional)", text: $subtitle)
                        .textInputAutocapitalization(.sentences)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: KindeksLayout.fieldCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: KindeksLayout.fieldCornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .foregroundStyle(.white)

                    Button("Save goal") {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        let ok = appState.addOwnDonationGoal(
                            title: t,
                            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                            imageData: imageData
                        )
                        if ok {
                            dismiss()
                        } else {
                            showLimitAlert = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.88))
                    .foregroundStyle(.black)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer(minLength: 0)
                }
                .padding(24)
            }
            .navigationTitle("New goal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .toolbarBackground(KindeksPalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .alert("Limit reached", isPresented: $showLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can store up to \(DonationGoalsLocalStore.maxGoalsPerAccount) goals on this device.")
        }
    }

    @ViewBuilder
    private var goalImagePickerContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KindeksLayout.fieldCornerRadius, style: .continuous)
                .fill(.white.opacity(0.12))
                .frame(height: 120)
            if let imageData, let ui = UIImage(data: imageData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: KindeksLayout.fieldCornerRadius, style: .continuous))
            } else if isLoadingAvatar {
                ProgressView().tint(.white)
            } else {
                Label("Add photo (optional)", systemImage: "photo.badge.plus")
                    .font(KindeksFont.regular(14))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func loadImage(from item: PhotosPickerItem) async {
        isLoadingAvatar = true
        defer { isLoadingAvatar = false }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data),
           let compressed = image.jpegData(compressionQuality: 0.78) {
            imageData = compressed
        }
    }
}
