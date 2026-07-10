import SwiftUI
import PhotosUI
import SwiftData

/// Snap a photo of your plate (or an apple) → AI identifies the food(s)
/// with portion estimates → tap to log. Backed by the server vision route.
struct FoodPhotoView: View {
    let slot: MealSlot

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    @State private var pickedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var image: UIImage?
    @State private var candidates: [FoodPhotoCandidate] = []
    @State private var loggedNames: Set<String> = []
    @State private var isAnalyzing = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
                            .accessibilityLabel("Food photo")
                    } else {
                        photoButtons
                    }

                    if isAnalyzing {
                        Card {
                            HStack(spacing: Theme.Spacing.sm) {
                                ProgressView()
                                Text("Identifying your food…")
                                    .font(Theme.Font.body17)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .font(Theme.Font.caption13)
                            .foregroundStyle(Theme.Color.error)
                            .multilineTextAlignment(.center)
                    }

                    ForEach(candidates) { candidate in
                        Button {
                            log(candidate)
                        } label: {
                            Card {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.name)
                                            .font(Theme.Font.bodyEmphasized17)
                                            .foregroundStyle(Theme.Color.textPrimary)
                                        Text("≈\(Int(candidate.estimatedGrams))g · \(Int(candidate.kcal)) kcal · P\(Int(candidate.protein)) C\(Int(candidate.carbs)) F\(Int(candidate.fat))")
                                            .font(Theme.Font.caption13)
                                            .foregroundStyle(Theme.Color.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: loggedNames.contains(candidate.name) ? "checkmark.circle.fill" : "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(Theme.Color.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(loggedNames.contains(candidate.name))
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Color.background)
            .navigationTitle("Photo Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loggedNames.isEmpty ? "Cancel" : "Done") { dismiss() }
                }
                if image != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Retake") {
                            image = nil
                            candidates = []
                            errorText = nil
                        }
                    }
                }
            }
            .onChange(of: pickedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let loaded = UIImage(data: data) {
                        await analyze(loaded)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView { captured in
                    Task { await analyze(captured) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var photoButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "camera.macro")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Color.accent)
                .padding(.top, Theme.Spacing.xl)
            Text("Photograph your plate —\nwe'll estimate the portion and macros")
                .font(Theme.Font.body17)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingCamera = true
            } label: {
                Label("Take photo", systemImage: "camera.fill")
                    .font(Theme.Font.bodyEmphasized17)
                    .foregroundStyle(Theme.Color.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.Color.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label("Choose from library", systemImage: "photo.on.rectangle")
                    .font(Theme.Font.bodyEmphasized17)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }

            if !container.auth.isSignedIn {
                Text("Photo logging needs a signed-in account (the vision AI runs server-side).")
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func analyze(_ photo: UIImage) async {
        image = photo
        errorText = nil
        candidates = []
        isAnalyzing = true
        defer { isAnalyzing = false }

        guard let jpeg = photo.resizedJPEG(maxDimension: 1024, quality: 0.7) else {
            errorText = "Couldn't process that photo."
            return
        }
        do {
            candidates = try await container.ai.analyzeFoodPhoto(jpegData: jpeg)
            if candidates.isEmpty {
                errorText = "No food recognized — try a clearer shot, or search instead."
            }
        } catch AIServiceError.unavailable {
            errorText = "Sign in (Profile tab) to log by photo."
        } catch {
            errorText = "Couldn't analyze the photo — check your connection and try again."
        }
    }

    private func log(_ candidate: FoodPhotoCandidate) {
        let grams = max(candidate.estimatedGrams, 1)
        // Store per-100g so re-logging at other portions scales correctly.
        let per100g = MacroSet(
            kcal: candidate.kcal * 100 / grams,
            protein: candidate.protein * 100 / grams,
            carbs: candidate.carbs * 100 / grams,
            fat: candidate.fat * 100 / grams
        )
        let item = FoodItem(name: candidate.name, source: .estimate, per100g: per100g)
        context.insert(item)
        context.insert(FoodLog(
            slot: slot,
            foodItemID: item.id,
            quantityG: grams,
            macroSnapshot: candidate.macroSet
        ))
        item.recordUse()
        try? context.save()
        loggedNames.insert(candidate.name)
        Haptics.light()
    }
}
