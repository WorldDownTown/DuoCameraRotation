import AVFoundation
import SwiftUI

struct ContentView: View {
    @State private var mode = RotationMode.interface
    @State private var status = ""
    @State private var camera = AVCaptureDevice.videoCameras.first { $0.position == .back }

    var body: some View {
        CameraPreview(mode: mode, camera: camera, status: $status)
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading) {
                    Text(status)
                        .font(.caption.monospaced())
                    Picker("Camera", selection: $camera) {
                        ForEach(AVCaptureDevice.videoCameras, id: \.self) { camera in
                            Text(camera.localizedName).tag(Optional(camera))
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("Rotation", selection: $mode) {
                        ForEach(RotationMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(.regularMaterial)
            }
    }
}
