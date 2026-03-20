import Foundation
import ARKit

struct GazePointConverter {

    /// 将用户的 3D 注视数据投影到 2D 屏幕坐标。
    ///
    /// 算法流程：
    /// 1. 计算双眼中点在世界坐标系中的位置
    /// 2. 将 ARFaceAnchor.lookAtPoint（面部坐标系中的位置点）变换到世界坐标系
    /// 3. 从双眼中点指向世界坐标系中的注视点，得到注视方向
    /// 4. 计算注视射线与摄像头前方虚拟平面的交点
    /// 5. 使用 ARCamera.projectPoint 将交点投影到屏幕坐标
    func projectGaze(faceAnchor: ARFaceAnchor, camera: ARCamera, viewSize: CGSize) -> CGPoint? {
        let headTransform = faceAnchor.transform

        // 1. 双眼中点 → 世界坐标系
        let leftEyePos = faceAnchor.leftEyeTransform.columns.3
        let rightEyePos = faceAnchor.rightEyeTransform.columns.3
        let eyesMidInHead = (leftEyePos + rightEyePos) / 2.0
        let eyesMidInWorld = (headTransform * eyesMidInHead).xyz

        // 2. 从眼球变换矩阵的 Z 轴提取注视方向（比 lookAtPoint 变化范围大得多）
        let leftGaze = faceAnchor.leftEyeTransform.columns.2.xyz   // 左眼 Z 轴 = 前向
        let rightGaze = faceAnchor.rightEyeTransform.columns.2.xyz  // 右眼 Z 轴 = 前向
        let avgGazeInFace = simd_normalize((leftGaze + rightGaze) / 2.0)

        // 3. 注视方向：面部坐标系 → 世界坐标系（w=0 纯方向，只旋转不平移）
        let gazeDirection = simd_normalize((headTransform * simd_float4(avgGazeInFace, 0)).xyz)

        // 4. 虚拟平面：垂直于摄像头前向，距离根据人脸到摄像头的实际距离动态计算
        let cameraPosition = camera.transform.columns.3.xyz
        let faceToCamera = simd_length(eyesMidInWorld - cameraPosition)
        let virtualPlaneDistance = max(0.2, faceToCamera * 0.9)

        let cameraForward = simd_normalize(-camera.transform.columns.2.xyz)
        let planePoint = cameraPosition + cameraForward * virtualPlaneDistance

        // 射线-平面交点
        let denominator = simd_dot(gazeDirection, cameraForward)
        guard abs(denominator) > Float.ulpOfOne else { return nil }

        let t = simd_dot(planePoint - eyesMidInWorld, cameraForward) / denominator
        guard t > 0 else { return nil }

        let intersection = eyesMidInWorld + gazeDirection * t

        // 5. 世界坐标 → 屏幕坐标
        return camera.projectPoint(intersection, orientation: .portrait, viewportSize: viewSize)
    }
}

// MARK: - SIMD Extensions

extension simd_float4 {
    var xyz: simd_float3 {
        simd_float3(x, y, z)
    }
}
