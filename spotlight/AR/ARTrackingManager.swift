import ARKit
import QuartzCore
import Observation

@Observable
class ARTrackingManager: NSObject, ARSessionDelegate {

    let session = ARSession()
    var gazeScreenPoint: CGPoint?
    var isTracking = false

    private let gazePointConverter = GazePointConverter()
    private let viewSize = UIScreen.main.bounds.size
    private var lastUpdateTime: CFTimeInterval = 0
    private let updateInterval: CFTimeInterval = 1.0 / 30.0

    override init() {
        super.init()
        session.delegate = self
    }

    func startSession() {
        guard ARFaceTrackingConfiguration.isSupported else {
            isTracking = false
            return
        }
        let config = ARFaceTrackingConfiguration()
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func pauseSession() {
        session.pause()
        isTracking = false
    }

    // MARK: - ARSessionDelegate（在后台线程调用）

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let now = CACurrentMediaTime()
        guard now - lastUpdateTime >= updateInterval else { return }
        lastUpdateTime = now

        let faceAnchor = frame.anchors.compactMap { $0 as? ARFaceAnchor }.first
        let point: CGPoint?

        if let faceAnchor {
            point = gazePointConverter.projectGaze(
                faceAnchor: faceAnchor,
                camera: frame.camera,
                viewSize: viewSize
            )
        } else {
            point = nil
        }

        DispatchQueue.main.async { [weak self] in
            self?.gazeScreenPoint = point
            self?.isTracking = faceAnchor != nil
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.gazeScreenPoint = nil
            self?.isTracking = false
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async { [weak self] in
            self?.gazeScreenPoint = nil
            self?.isTracking = false
        }
    }
}
