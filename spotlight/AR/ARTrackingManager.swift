import ARKit
import QuartzCore
import Observation

@Observable
class ARTrackingManager: NSObject, ARSessionDelegate {

    let session = ARSession()
    var gazeScreenPoint: CGPoint?
    var isTracking = false

    /// 校准数据（已校准时使用仿射变换投影）
    var calibrationData: CalibrationData?

    /// 校准管理器（校准模式下采集原始数据）
    var calibrationManager: CalibrationManager?

    private var gazePointConverter = GazePointConverter()
    private let viewSize = UIScreen.main.bounds.size
    private var lastUpdateTime: CFTimeInterval = 0
    private let updateInterval: CFTimeInterval = 1.0 / 30.0

    // 眨眼检测
    private let blinkThreshold: Float = 0.5
    private var lastValidGazePoint: CGPoint?

    // EMA 平滑（smoothingFactor=0.55 → 新值权重 0.45，约 4 帧延迟，显著减少跳动）
    var smoothingFactor: Float = 0.55
    private var smoothedPoint: CGPoint?

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

        let (point, tracking) = autoreleasepool { () -> (CGPoint?, Bool) in
            guard let faceAnchor = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
                return (nil, false)
            }

            // 眨眼检测：任一眼 blend shape > 阈值时冻结注视点
            let leftBlink = faceAnchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
            let rightBlink = faceAnchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0
            if leftBlink > blinkThreshold || rightBlink > blinkThreshold {
                return (lastValidGazePoint, true)
            }

            // 校准模式：将原始 tan 值发送给 CalibrationManager
            if let cm = calibrationManager {
                if let angles = gazePointConverter.extractRawGazeAngles(
                    faceAnchor: faceAnchor, camera: frame.camera) {
                    let tanX = angles.0, tanY = angles.1
                    DispatchQueue.main.async {
                        cm.addSample(tanX: tanX, tanY: tanY)
                    }
                }
            }

            // 投影：有校准数据时用仿射变换，否则用默认灵敏度放大
            let rawPoint: CGPoint?
            if let cal = calibrationData {
                rawPoint = gazePointConverter.projectGazeWithCalibration(
                    faceAnchor: faceAnchor, camera: frame.camera,
                    viewSize: viewSize, calibration: cal)
            } else {
                rawPoint = gazePointConverter.projectGaze(
                    faceAnchor: faceAnchor, camera: frame.camera, viewSize: viewSize)
            }

            // EMA 平滑
            let finalPoint: CGPoint?
            if let raw = rawPoint {
                if let prev = smoothedPoint {
                    let alpha = CGFloat(1.0 - smoothingFactor)
                    let smoothed = CGPoint(
                        x: prev.x + alpha * (raw.x - prev.x),
                        y: prev.y + alpha * (raw.y - prev.y))
                    smoothedPoint = smoothed
                    finalPoint = smoothed
                } else {
                    smoothedPoint = raw
                    finalPoint = raw
                }
                lastValidGazePoint = finalPoint
            } else {
                finalPoint = rawPoint
            }

            return (finalPoint, true)
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
