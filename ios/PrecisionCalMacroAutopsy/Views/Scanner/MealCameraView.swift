import SwiftUI
import AVFoundation

/// Live meal-photo capture screen. Runs the real AVFoundation pipeline
/// (capture session + photo output), discovers built-in AND external
/// (simulator-injected) cameras, and hands the captured JPEG to the caller
/// for the 6-pass analysis. Shows a distinct denied state (Settings link)
/// separate from the no-device empty state.
struct MealCameraScreen: View {
    var onCapture: (Data) -> Void
    var onCancel: () -> Void

    @State private var permission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    /// Discovery includes `.external` so an injected webcam is found in preview.
    private var hasCameraDevice: Bool {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .back
        )
        return !discovery.devices.isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch permission {
            case .authorized:
                if hasCameraDevice {
                    MealCaptureCamera(onCapture: onCapture, onCancel: onCancel)
                } else {
                    noDeviceView
                }
            case .notDetermined:
                ProgressView()
                    .tint(.white)
            default:
                deniedView
            }
        }
        .task {
            if permission == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                permission = granted ? .authorized : .denied
            }
        }
    }

    // MARK: - Denied state

    private var deniedView: some View {
        VStack(spacing: 18) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.85))
            Text("Camera access is off")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text("Enable camera access in Settings to snap live photos of your meals. You can also choose a photo from your library instead.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.terracottaDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.white, in: .rect(cornerRadius: 14))
            }
            .padding(.horizontal, 36)

            Button {
                onCancel()
            } label: {
                Text("Back to photo picker")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(height: 44)
            }
        }
    }

    // MARK: - No-device state

    private var noDeviceView: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.on.rectangle")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.85))
            Text("No camera available")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text("A camera isn't detected on this device. Choose a photo from your library instead.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)

            Button {
                onCancel()
            } label: {
                Text("Back to photo picker")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.terracottaDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.white, in: .rect(cornerRadius: 14))
            }
            .padding(.horizontal, 36)
        }
    }
}

// MARK: - UIKit bridge

private struct MealCaptureCamera: UIViewControllerRepresentable {
    var onCapture: (Data) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> MealCameraVC {
        MealCameraVC(onCapture: onCapture, onCancel: onCancel)
    }

    func updateUIViewController(_ uiViewController: MealCameraVC, context: Context) {}
}

/// Real AVCaptureSession + AVCapturePhotoOutput view controller with a native
/// shutter button, cancel button, and framing hint.
final class MealCameraVC: UIViewController, AVCapturePhotoCaptureDelegate {
    private let onCapture: (Data) -> Void
    private let onCancel: () -> Void

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isCaptured = false

    private var shutterButton: UIButton!
    private var cancelButton: UIButton!
    private var hintLabel: UILabel!

    init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildControls()
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            let session = self.session
            Task.detached(priority: .userInitiated) { session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    // MARK: - Session

    private func configureSession() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .back
        )
        guard let device = discovery.devices.first ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview
    }

    // MARK: - Controls

    private func buildControls() {
        // Framing hint
        let hint = UILabel()
        hint.text = "Frame your plate in the center"
        hint.font = .systemFont(ofSize: 13, weight: .semibold)
        hint.textColor = .white
        hint.textAlignment = .center
        hint.numberOfLines = 1
        hint.layer.cornerRadius = 15
        hint.layer.masksToBounds = true
        hint.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)
        hintLabel = hint

        // Cancel
        let cancel = UIButton(type: .system)
        cancel.setImage(UIImage(systemName: "xmark"), for: .normal)
        cancel.tintColor = .white
        cancel.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        cancel.layer.cornerRadius = 20
        cancel.layer.masksToBounds = true
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancel)
        cancelButton = cancel

        // Shutter
        let shutter = UIButton(type: .custom)
        shutter.backgroundColor = .white
        shutter.layer.cornerRadius = 36
        shutter.layer.borderWidth = 4
        shutter.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
        shutter.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        shutter.translatesAutoresizingMaskIntoConstraints = false
        shutter.accessibilityLabel = "Take photo"
        view.addSubview(shutter)
        shutterButton = shutter

        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hint.heightAnchor.constraint(equalToConstant: 32),
            hint.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),

            cancel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cancel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancel.widthAnchor.constraint(equalToConstant: 40),
            cancel.heightAnchor.constraint(equalToConstant: 40),

            shutter.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            shutter.widthAnchor.constraint(equalToConstant: 72),
            shutter.heightAnchor.constraint(equalToConstant: 72),
        ])
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        onCancel()
    }

    @objc private func shutterTapped() {
        guard !isCaptured, session.isRunning else { return }
        isCaptured = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        shutterButton.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0.5) {
            self.shutterButton.transform = .identity
        }

        let settings = AVCapturePhotoSettings()
        if let connection = photoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data: Data? = (error == nil) ? photo.fileDataRepresentation() : nil
        Task { @MainActor in
            guard let data else {
                self.isCaptured = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.onCapture(data)
        }
    }
}
