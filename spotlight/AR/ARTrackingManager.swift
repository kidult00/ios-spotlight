import Foundation
import ARKit
import Combine
import UIKit // Needed for UIScreen and CGSize for GazePointConverter

class ARTrackingManager: NSObject, ARSessionDelegate, ObservableObject {

    let session = ARSession()
    private let gazePointConverter = GazePointConverter() // Add instance of GazePointConverter
    
    // Published properties to make AR data available to other parts of the app
    @Published var currentFaceAnchor: ARFaceAnchor? // 当检测到面部时，这个属性会被更新
    @Published var currentFrame: ARFrame?   // ARKit 渲染每一帧时，这个属性会被更新
    @Published var gazeScreenPoint: CGPoint? // 存储计算出的2D屏幕注视点

    override init() {
        super.init()
        session.delegate = self
    }

    func startSession() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("ARFaceTracking is not supported on this device.")
            self.gazeScreenPoint = nil // Ensure gaze point is nil if not supported
            return
        }

        let configuration = ARFaceTrackingConfiguration()
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        print("ARSession started with face tracking configuration.")
    }

    func pauseSession() {
        session.pause()
        print("ARSession paused.")
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Publish the current frame
        self.currentFrame = frame
        
        // Attempt to get the face anchor from this frame's anchors
        if self.currentFaceAnchor == nil {
             self.currentFaceAnchor = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first
        }
        
        // Calculate gaze point if we have all necessary data
        updateGazePoint()
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        if let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first {
            self.currentFaceAnchor = faceAnchor
            // Potentially call updateGazePoint() here as well, or rely on didUpdate frame
            // For simplicity, let's keep the main calculation in didUpdate frame
            // as we need the camera data from the frame.
            // If didUpdate frame is frequent enough, this might be redundant.
            // However, if face anchor updates are more critical or frequent, consider it.
            // For now, we ensure currentFaceAnchor is updated.
        }
        // If a face anchor is removed, currentFaceAnchor might become nil if not updated by frame.anchors
        // Consider explicitly setting currentFaceAnchor to nil if all face anchors are removed.
        // Corrected line below:
        if !anchors.contains(where: { $0 is ARFaceAnchor }) && (self.currentFrame?.anchors.compactMap({ $0 as? ARFaceAnchor }).isEmpty ?? true) {
            self.currentFaceAnchor = nil
        }
        updateGazePoint() // Recalculate if anchors changed (e.g., face lost)
    }

    private func updateGazePoint() {
        guard let faceAnchor = self.currentFaceAnchor,
              let camera = self.currentFrame?.camera else {
            // Always print when this guard fails to understand why
            print("ARTrackingManager: updateGazePoint() guard failed.")
            if self.currentFaceAnchor == nil {
                print("ARTrackingManager: currentFaceAnchor is nil.")
            }
            if self.currentFrame == nil {
                print("ARTrackingManager: currentFrame is nil.")
            } else if self.currentFrame?.camera == nil {
                print("ARTrackingManager: currentFrame.camera is nil.")
            }
            
            if self.gazeScreenPoint != nil {
                print("ARTrackingManager: Clearing gazeScreenPoint.")
            }
            self.gazeScreenPoint = nil
            return
        }

        print("ARTrackingManager: Valid faceAnchor and camera found. Proceeding to GazePointConverter.")
        // print("ARTrackingManager: FaceAnchor lookAtPoint: \(faceAnchor.lookAtPoint)") // Uncomment for more detail if needed
        // print("ARTrackingManager: Camera transform: \(camera.transform)") // Uncomment for more detail if needed

        let viewSize = UIScreen.main.bounds.size
        // print("ARTrackingManager: Using viewSize: \(viewSize)") // Uncomment for more detail if needed
        
        let calculatedPoint = gazePointConverter.projectGaze(faceAnchor: faceAnchor, camera: camera, viewSize: viewSize)
        
        if let point = calculatedPoint {
            print("ARTrackingManager: Calculated Gaze Point by Converter: \(point)")
            self.gazeScreenPoint = point
        } else {
            print("ARTrackingManager: GazePointConverter returned nil.")
            if self.gazeScreenPoint != nil {
                 print("ARTrackingManager: Clearing gazeScreenPoint because converter returned nil.")
            }
            self.gazeScreenPoint = nil
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("ARSession failed with error: \(error.localizedDescription)")
        self.currentFaceAnchor = nil
        self.currentFrame = nil
        self.gazeScreenPoint = nil
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("ARSession was interrupted.")
        self.currentFaceAnchor = nil
        self.currentFrame = nil
        self.gazeScreenPoint = nil
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("ARSession interruption ended.")
        // Reset tracking or reconfigure the session if needed
        // Consider restarting the session or providing UI to do so
    }

    // MARK: - Accessing Tracking Data (Derived from @Published properties)
    // These methods can still be useful for direct access if needed,
    // but reactive updates should primarily use the @Published properties.

    func getLookAtPoint() -> simd_float3? {
        return currentFaceAnchor?.lookAtPoint
    }

    func getLeftEyeTransform() -> simd_float4x4? {
        return currentFaceAnchor?.leftEyeTransform
    }

    func getRightEyeTransform() -> simd_float4x4? {
        return currentFaceAnchor?.rightEyeTransform
    }

    func getHeadTransform() -> simd_float4x4? {
        return currentFaceAnchor?.transform
    }
}