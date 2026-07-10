import SwiftUI
import PhotosUI
import SwiftData

/// "Point your camera at the equipment" flow: photo → AI identifies the
/// gear + any readable weight → personalized exercise suggestions → pick
/// one and the first set is pre-filled with the detected weight.
struct EquipmentPhotoView: View {
    /// Picked exercise + weight (kg) read from the photo, if any.
    let onPick: (Exercise, Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppContainer.self) private var container
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var pickedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var image: UIImage?
    @State private var analysis: EquipmentAnalysis?
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
                            .accessibilityLabel("Equipment photo")
                    } else {
                        photoButtons
                    }

                    if isAnalyzing {
                        Card {
                            HStack(spacing: Theme.Spacing.sm) {
                                ProgressView()
                                Text("Looking at your equipment…")
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

                    if let analysis {
                        analysisResults(analysis)
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Color.background)
            .navigationTitle("Snap Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if image != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Retake") {
                            image = nil
                            analysis = nil
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
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Color.accent)
                .padding(.top, Theme.Spacing.xl)
            Text("Photograph the machine, dumbbells,\nor bar you're about to use")
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
                Text("Equipment photos need a signed-in account (the vision AI runs server-side).")
                    .font(Theme.Font.caption13)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private func analysisResults(_ analysis: EquipmentAnalysis) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Card {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.Color.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(analysis.equipment)
                            .font(Theme.Font.bodyEmphasized17)
                            .foregroundStyle(Theme.Color.textPrimary)
                        if let weight = analysis.detectedWeightKG {
                            Text("Detected: \(Units.formatWeight(weight, unit: .imperial)) / \(Units.formatWeight(weight, unit: .metric))")
                                .font(Theme.Font.caption13)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                    Spacer()
                }
            }

            Text("Suggested for you")
                .font(Theme.Font.caption13)
                .foregroundStyle(Theme.Color.textSecondary)

            ForEach(analysis.suggestions) { suggestion in
                Button {
                    pick(suggestion, weightKG: analysis.detectedWeightKG)
                } label: {
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.exerciseName)
                                    .font(Theme.Font.bodyEmphasized17)
                                    .foregroundStyle(Theme.Color.textPrimary)
                                Text(suggestion.reason)
                                    .font(Theme.Font.caption13)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.Color.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func analyze(_ photo: UIImage) async {
        image = photo
        errorText = nil
        analysis = nil
        isAnalyzing = true
        defer { isAnalyzing = false }

        guard let jpeg = photo.resizedJPEG(maxDimension: 1024, quality: 0.7) else {
            errorText = "Couldn't process that photo."
            return
        }
        do {
            analysis = try await container.ai.analyzeEquipmentPhoto(jpegData: jpeg)
        } catch AIServiceError.unavailable {
            errorText = "Sign in (Profile tab) to use equipment photos — the vision AI runs server-side."
        } catch {
            errorText = "Couldn't analyze the photo — check your connection and try again."
        }
    }

    /// Matches the AI's suggested name to the local library, creating a
    /// custom exercise if it's genuinely new.
    private func pick(_ suggestion: EquipmentAnalysis.Suggestion, weightKG: Double?) {
        let match = exercises.first { $0.name.localizedCaseInsensitiveCompare(suggestion.exerciseName) == .orderedSame }
            ?? exercises.first { $0.name.localizedCaseInsensitiveContains(suggestion.exerciseName) || suggestion.exerciseName.localizedCaseInsensitiveContains($0.name) }

        let exercise: Exercise
        if let match {
            exercise = match
        } else {
            exercise = Exercise(name: suggestion.exerciseName, muscleGroups: [], equipment: "other", isCustom: true)
            context.insert(exercise)
            try? context.save()
        }
        onPick(exercise, weightKG)
        Haptics.success()
        dismiss()
    }
}

// MARK: - Camera + resize helpers

/// Minimal UIImagePickerController wrapper for in-place camera capture
/// (PhotosPicker has no camera source).
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

extension UIImage {
    /// Downscale + JPEG-compress before upload: keeps vision requests fast
    /// and inside the backend's payload cap.
    func resizedJPEG(maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return jpegData(compressionQuality: quality) }
        let scale = maxDimension / largest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
