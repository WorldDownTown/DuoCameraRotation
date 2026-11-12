import AVFoundation
import SwiftUI

enum RotationMode: String, CaseIterable, Identifiable {
    case interface
    case device
    case coordinator

    var id: Self { self }
}

struct CameraPreview: UIViewRepresentable {
    let mode: RotationMode
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
    }
}

final class PreviewView: UIView {
    var mode = RotationMode.interface {
        didSet { applyRotation() }
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
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onStatusChange?("camera unavailable")
            return
        }
        session.addInput(input)
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        self.coordinator = coordinator
        observation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] _, _ in
            self?.applyRotation()
        }

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
