import SwiftUI

struct ContentView: View {
    @State private var mode = RotationMode.interface
    @State private var status = ""

    var body: some View {
        CameraPreview(mode: mode, status: $status)
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading) {
                    Text(status)
                        .font(.caption.monospaced())
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
