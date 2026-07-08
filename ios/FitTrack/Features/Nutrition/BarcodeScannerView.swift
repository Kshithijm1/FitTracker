import SwiftUI
import VisionKit
import AVFoundation

/// VisionKit barcode scan sheet → OFF lookup (PLAN.md §3/§7). Shows a
/// permission-rationale screen before the system camera prompt, and a
/// plain-language fallback when running somewhere the scanner can't (the
/// Simulator, or a device without the required hardware).
struct BarcodeScannerView: View {
    let onScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var hasRequestedPermission = false

    var body: some View {
        NavigationStack {
            Group {
                if !DataScannerViewController.isSupported {
                    ContentUnavailableView(
                        "Barcode scanning unavailable",
                        systemImage: "barcode.viewfinder",
                        description: Text("This device or simulator doesn't support the barcode scanner. Use search or freeform instead.")
                    )
                } else if authorizationStatus == .authorized {
                    DataScannerRepresentable(onScanned: onScanned)
                } else if hasRequestedPermission {
                    ContentUnavailableView(
                        "Camera access needed",
                        systemImage: "camera",
                        description: Text("Enable camera access in Settings to scan barcodes.")
                    )
                } else {
                    permissionRationale
                }
            }
            .navigationTitle("Scan Barcode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var permissionRationale: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Color.accent)
            Text("Scan a food barcode")
                .font(Theme.Font.title22)
            Text("FitTrack uses the camera only to read the barcode — no photos are taken or stored.")
                .font(Theme.Font.body17)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
            Button("Enable Camera") {
                Task {
                    _ = await AVCaptureDevice.requestAccess(for: .video)
                    authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    hasRequestedPermission = true
                }
            }
        }
        .padding(Theme.Spacing.lg)
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScanned: (String) -> Void
        private var hasScanned = false

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned, let item = addedItems.first, case let .barcode(barcode) = item,
                  let payload = barcode.payloadStringValue else { return }
            hasScanned = true
            dataScanner.stopScanning()
            onScanned(payload)
        }
    }
}
