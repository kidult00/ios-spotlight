import Foundation
import ARKit

struct GazePointConverter {

    /// 将用户的 3D 注视数据投影到 2D 屏幕坐标。
    ///
    /// 算法：基于注视角度的直接投影
    /// 1. 从眼球旋转矩阵提取注视方向，转换到世界坐标系
    /// 2. 将注视方向转到摄像头坐标系，计算角度偏移量（tanX, tanY）
    /// 3. 在摄像头前方构造合成 3D 点，用 projectPoint 投影到屏幕
    ///
    /// 旧方法（射线-虚拟平面交点）的问题：虚拟平面距人脸太近（仅 3cm），
    /// 导致不同注视角度的交点几乎重合，投影灵敏度仅为屏幕宽度的 2-3%。
    func projectGaze(faceAnchor: ARFaceAnchor, camera: ARCamera, viewSize: CGSize) -> CGPoint? {
        let headTransform = faceAnchor.transform

        // 1. 从眼球变换矩阵的 Z 轴提取注视方向（比 lookAtPoint 变化范围大）
        let leftGaze = faceAnchor.leftEyeTransform.columns.2.xyz
        let rightGaze = faceAnchor.rightEyeTransform.columns.2.xyz
        let avgGazeInFace = simd_normalize((leftGaze + rightGaze) / 2.0)

        // 注视方向：面部坐标系 → 世界坐标系（w=0 纯方向，只旋转不平移）
        let gazeWorld = simd_normalize((headTransform * simd_float4(avgGazeInFace, 0)).xyz)

        // 2. 注视方向 → 摄像头坐标系
        //    摄像头坐标系：+X 右, +Y 上, -Z 前向（朝用户）
        //    注视从用户指向摄像头 → gazeInCam.z > 0
        let camInverse = simd_inverse(camera.transform)
        let gazeInCam = (camInverse * simd_float4(gazeWorld, 0)).xyz

        guard gazeInCam.z > 0.01 else { return nil }

        // 3. 注视角度偏移量（注视方向在摄像头坐标系中的 tan 值）
        let tanX = gazeInCam.x / gazeInCam.z
        let tanY = gazeInCam.y / gazeInCam.z

        // 4. 在摄像头前方 1m 处按注视角度构造合成 3D 点
        //    这样 projectPoint 基于角度而非距离来投影，灵敏度大幅提升
        let syntheticInCam = simd_float4(tanX, tanY, -1.0, 1.0)
        let syntheticInWorld = (camera.transform * syntheticInCam).xyz

        // 5. projectPoint 处理 portrait 方向旋转和视口映射
        return camera.projectPoint(syntheticInWorld, orientation: .portrait, viewportSize: viewSize)
    }
}

// MARK: - SIMD Extensions

extension simd_float4 {
    var xyz: simd_float3 {
        simd_float3(x, y, z)
    }
}
