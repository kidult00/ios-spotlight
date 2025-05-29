import Foundation
import ARKit // For simd_float3, simd_float4x4 etc.
import UIKit // For CGPoint, UIScreen

class GazePointConverter {

    // This class will be responsible for converting 3D gaze data from ARKit
    // into 2D screen coordinates.

    // We might need a reference to the ARSCNView or ARView if using projectPoint,
    // or screen dimensions if doing manual projection.
    // For now, let's assume we'll get necessary parameters passed into methods.

    init() {
        // Initialization, if any
    }

    // Placeholder method - this will be significantly more complex.
    // It needs the ARSCNView/ARView or camera parameters to project points.
    // Or, it might take eye transforms and calculate intersection with a virtual screen plane.
    func convertToScreenPoint(
        lookAtPoint: simd_float3, // In face local coordinates
        headTransform: simd_float4x4,
        leftEyeTransform: simd_float4x4,
        rightEyeTransform: simd_float4x4,
        camera: ARCamera // Provides projection matrix and view matrix
        // viewSize: CGSize // Size of the view rendering the AR content
    ) -> CGPoint? {
        // This is a very simplified placeholder and NOT a correct implementation.
        // Actual implementation will involve matrix math and projection.
        // For example, using ARCamera's projectPoint method if we have a world-space point.

        // 1. Transform eye positions to world space (or camera space)
        // 2. Determine gaze vector in world space (or camera space)
        // 3. Intersect gaze vector with a virtual screen plane or use ARCamera.projectPoint
        
        // Example of what might be needed if we had a 3D point in world space:
        // let pointInWorld = ...
        // let projectedPoint = camera.projectPoint(pointInWorld, orientation: .portrait, viewportSize: viewSize)
        // return projectedPoint

        print("GazePointConverter.convertToScreenPoint called (placeholder)")
        return CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY) // Dummy center point
    }
    
    // Alternative approach: Projecting a point on a virtual plane in front of the camera
    // This method is also a placeholder and needs proper implementation
    func projectGaze(faceAnchor: ARFaceAnchor, camera: ARCamera, viewSize: CGSize) -> CGPoint? {
        // Get the transform of the head
        let headTransform = faceAnchor.transform
        
        // Get the transform of the eyes relative to the head
        let leftEyeTransform = faceAnchor.leftEyeTransform
        let rightEyeTransform = faceAnchor.rightEyeTransform
        
        // Calculate the midpoint between the eyes in head coordinates
        // Ensure we are using the translation part of the transform matrix (w-component is 1 for points)
        let leftEyePositionInHead = leftEyeTransform.columns.3
        let rightEyePositionInHead = rightEyeTransform.columns.3
        let eyesMidPointInHeadSpace = (leftEyePositionInHead + rightEyePositionInHead) / 2.0 // This is simd_float4
        
        // Transform the midpoint of the eyes to world space
        let eyesMidPointInWorldSpace_simd4 = headTransform * eyesMidPointInHeadSpace
        let eyesMidPointInWorldSpace = eyesMidPointInWorldSpace_simd4.xyz // Extract simd_float3
        
        print("GazePointConverter: Eyes Midpoint in World Space: \(eyesMidPointInWorldSpace)")

        // Gaze direction: ARKit's lookAtPoint is a point in the face coordinate system that the user is looking at.
        // We need to form a vector from the eye's origin towards this point, then transform to world space.
        // A simplified approach: assume lookAtPoint is a direction vector from the center of the face.
        // Transform this direction from face space to world space.
        // A direction vector should be transformed by multiplying with the 3x3 rotation part of the transform matrix.
        // The w-component of the direction vector should be 0.
        let lookAtPointInFaceSpace_simd3 = faceAnchor.lookAtPoint
        let lookAtDirectionInFaceSpace_simd4 = simd_float4(lookAtPointInFaceSpace_simd3.x, lookAtPointInFaceSpace_simd3.y, lookAtPointInFaceSpace_simd3.z, 0)
        
        // Transform direction from face space to world space
        // We only want to rotate the direction, not translate it. So, use the rotation part of headTransform.
        // Or, ensure the w-component of the vector is 0 when multiplying by the full 4x4 matrix.
        let gazeDirectionInWorld_simd4 = headTransform * lookAtDirectionInFaceSpace_simd4
        let gazeVectorInWorld = simd_normalize(gazeDirectionInWorld_simd4.xyz) // Normalize to get a unit vector

        print("GazePointConverter: Gaze Vector in World Space (normalized): \(gazeVectorInWorld)")

        // Define a virtual plane some distance in front of the camera
        // Adjusted virtualPlaneDistance to be very close to the camera, representing the screen.
        // Original value was 0.5, which could be too far if eyes are closer to device.
        let virtualPlaneDistance: Float = 0.02 // meters (2cm in front of camera)
        
        let cameraTransform = camera.transform
        let cameraPositionInWorld = cameraTransform.columns.3.xyz
        // Camera's forward vector is the negative Z-axis in its local coordinate system.
        // Transformed to world space, it's the negative third column of the camera's transform matrix (if it's view-to-world).
        // ARCamera.transform is world-to-camera. So, its inverse is camera-to-world.
        // The Z-axis of the camera in world space is camera_to_world_transform.columns.2.xyz
        // The forward direction (what camera is looking at) is -Z.
        let cameraForwardInWorld = simd_normalize(-camera.transform.columns.2.xyz) // Negative Z-axis of camera in world

        // print("GazePointConverter: Camera Forward in World Space: \(cameraForwardInWorld)")

        // Plane normal is the camera's forward direction
        let planeNormal = cameraForwardInWorld
        // A point on the plane: camera's position + forward_vector * distance
        let pointOnPlane = cameraPositionInWorld + planeNormal * virtualPlaneDistance
        
        // Calculate intersection of the gaze ray with the virtual plane
        // Ray origin: eyesMidPointInWorldSpace
        // Ray direction: gazeVectorInWorld
        
        let denominator = dot(gazeVectorInWorld, planeNormal)
        print("GazePointConverter: Denominator for t: \(denominator)")

        if abs(denominator) < Float.ulpOfOne { // Ray is parallel to the plane, no intersection or infinite
            // print("GazePointConverter: Ray is parallel to the plane.")
            return nil
        }
        
        let t = dot(pointOnPlane - eyesMidPointInWorldSpace, planeNormal) / denominator
        // print("GazePointConverter: t = \(t)")
        
        if t < 0.01 { // Intersection is behind the ray origin or too close, likely not valid
            // print("GazePointConverter: Intersection is behind or too close to ray origin (t=\(t)).")
            return nil
        }
        
        let intersectionPointInWorld = eyesMidPointInWorldSpace + gazeVectorInWorld * t
        // print("GazePointConverter: Intersection Point in World Space: \(intersectionPointInWorld)")
        
        // Project this 3D world point to 2D screen coordinates
        // The viewportSize should ideally be the actual size of the ARSCNView.
        let projectedPoint = camera.projectPoint(intersectionPointInWorld,
                                                 orientation: .portrait, // Adjust if landscape
                                                 viewportSize: viewSize)
        
        // Corrected part:
        // Since projectPoint returns CGPoint (non-optional), we don't need 'if let'
        print("GazePointConverter: Projected to Screen Point: \(projectedPoint)")
        // The 'else' case for 'camera.projectPoint returned nil' is no longer applicable
        // if the method indeed always returns a non-optional CGPoint.
        
        return projectedPoint
    }
}

extension simd_float4x4 {
    var xyz: simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }
}

extension simd_float4 {
    var xyz: simd_float3 {
        return simd_float3(x, y, z)
    }
}