import SwiftUI
import AVFoundation

/// Real AVFoundation barcode reader. Cloud simulator has no camera so this view
/// is wrapped by `CameraProxyView` which shows a placeholder when no device is present.
struct BarcodeCameraView: UIViewControllerRepresentable {
    var onScanned: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScanned: onScanned) }

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.coordinator = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScanned: (String) -> Void
        var didScan = false

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        nonisolated func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            Task { @MainActor in
                guard !self.didScan else { return }
                self.didScan = true
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.success)
                self.onScanned(value)
            }
        }
    }

    final class ScannerVC: UIViewController {
        weak var coordinator: Coordinator?
        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configureSession()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.layer.bounds
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if !session.isRunning {
                Task.detached { [session] in session.startRunning() }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning { session.stopRunning() }
        }

        private func configureSession() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }

            session.beginConfiguration()
            if session.canAddInput(input) { session.addInput(input) }

            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(coordinator, queue: .main)
                output.metadataObjectTypes = [
                    .ean8, .ean13, .upce, .code128, .code39, .code93, .qr, .pdf417, .dataMatrix, .itf14,
                ]
            }
            session.commitConfiguration()

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.layer.bounds
            view.layer.insertSublayer(preview, at: 0)
            previewLayer = preview
        }
    }
}

/// Cloud-simulator placeholder. Shows on-device build once installed, otherwise
/// the user can type a barcode for testing.
struct CameraProxyView<RealCamera: View>: View {
    var realCamera: () -> RealCamera
    var onManualBarcode: (String) -> Void

    @State private var manualEntry: String = ""

    private var hasCamera: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    var body: some View {
        if hasCamera {
            realCamera()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 18) {
            BreathingOrb(size: 80, color: .white)
                .padding(.bottom, 4)
            Text("Camera unavailable in preview")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Install this app on your device via the Rork App to use the camera.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                TextField("", text: $manualEntry, prompt: Text("Type barcode (e.g. 0049000028911)").foregroundStyle(.white.opacity(0.5)))
                    .keyboardType(.numberPad)
                    .foregroundStyle(.white)
                    .tint(PrecisionCalTheme.terracotta)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    }

                Button {
                    let trimmed = manualEntry.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onManualBarcode(trimmed)
                } label: {
                    Text("Look up product")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(.white, in: .rect(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
        }
    }
}
