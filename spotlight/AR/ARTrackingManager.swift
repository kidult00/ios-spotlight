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

        // autoreleasepool 确保 ARFaceAnchor/ARCamera 等对象在 dispatch 前释放，
        // 避免 ARFrame 在自动释放池中积压触发 "retaining ARFrames" 警告
        let (point, tracking) = autoreleasepool { () -> (CGPoint?, Bool) in
            let faceAnchor = frame.anchors.compactMap { $0 as? ARFaceAnchor }.first
            let pt: CGPoint?
            if let faceAnchor {
                pt = gazePointConverter.projectGaze(
                    faceAnchor: faceAnchor, camera: frame.camera, viewSize: viewSize)
            } else {
                pt = nil
            }
            return (pt, faceAnchor != nil)
        }

        DispatchQueue.main.async { [weak self] in
            self?.gazeScreenPoint = point
            self?.isTracking = tracking
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
