import AVFoundation
import SwiftUI

enum RotationMode: String, CaseIterable, Identifiable {
    case interface
    case device
    case coordinator

    var id: Self { self }
}

extension AVCaptureDevice {
    static let videoCameras = DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
        mediaType: .video,
        position: .unspecified
    ).devices
}

struct CameraPreview: UIViewRepresentable {
    let mode: RotationMode
    let camera: AVCaptureDevice?
    @Binding var status: String

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.onStatusChange = { status in
            DispatchQueue.main.async { self.status = status }
        }
        view.start()
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.mode = mode
        view.camera = camera
    }
}

final class PreviewView: UIView {
    var mode = RotationMode.interface {
        didSet { applyRotation() }
    }
    var camera: AVCaptureDevice? {
        didSet {
            if camera != oldValue { switchCamera() }
        }
    }
    var onStatusChange: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var coordinator: AVCaptureDevice.RotationCoordinator?
    private var observation: NSKeyValueObservation?
    private var deviceOrientationObserver: NSObjectProtocol?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                guard granted else {
                    self.onStatusChange?("camera access denied")
                    return
                }
                self.configure()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyRotation()
    }

    private func configure() {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        switchCamera()

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        deviceOrientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.applyRotation()
        }

        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    private func switchCamera() {
        guard previewLayer.session != nil else { return }

        observation = nil
        coordinator = nil
        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        guard let device = camera,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            onStatusChange?("camera unavailable")
            return
        }
        session.addInput(input)
        session.commitConfiguration()

        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        self.coordinator = coordinator
        observation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] _, _ in
            self?.applyRotation()
        }
    }

    private func applyRotation() {
        guard let connection = previewLayer.connection,
              let interfaceOrientation = window?.windowScene?.interfaceOrientation,
              let coordinator else {
            return
        }

        switch mode {
        case .interface:
            connection.videoOrientation = AVCaptureVideoOrientation(interfaceOrientation)
        case .device:
            let angle = UIDevice.current.orientation.fixedVideoRotationAngle
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        case .coordinator:
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }

        onStatusChange?("""
            camera:               \(coordinator.device?.localizedName ?? "unknown")
            interfaceOrientation: \(interfaceOrientation.name)
            deviceOrientation:    \(UIDevice.current.orientation.name)
            coordinator angle:    \(Int(coordinator.videoRotationAngleForHorizonLevelPreview))
            applied angle:        \(Int(connection.videoRotationAngle))
            """)
    }
}

private extension AVCaptureVideoOrientation {
    init(_ orientation: UIInterfaceOrientation) {
        switch orientation {
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: self = .portrait
        }
    }
}

private extension UIInterfaceOrientation {
    var name: String {
        switch self {
        case .portrait: "portrait"
        case .portraitUpsideDown: "portraitUpsideDown"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        default: "unknown"
        }
    }
}

private extension UIDeviceOrientation {
    var fixedVideoRotationAngle: CGFloat {
        switch self {
        case .landscapeLeft: 0
        case .landscapeRight: 180
        case .portraitUpsideDown: 270
        default: 90
        }
    }

    var name: String {
        switch self {
        case .portrait: "portrait"
        case .portraitUpsideDown: "portraitUpsideDown"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        case .faceUp: "faceUp"
        case .faceDown: "faceDown"
        default: "unknown"
        }
    }
}
