import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {

    let session: ARSession

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session = session
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField]
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
