import Foundation
import ARKit

struct GazePointConverter {

    /// 水平灵敏度乘数。ARKit 眼球旋转约 ±12°，前置摄像头 FOV 约 60°，
    /// 需要 ~2.5x 放大才能覆盖全屏宽度。
    var sensitivityX: Float = 2.5

    /// 垂直灵敏度乘数。Portrait 屏幕更长且眼球垂直旋转范围更小，需要稍大放大。
    var sensitivityY: Float = 3.0

    /// 将用户的 3D 注视数据投影到 2D 屏幕坐标。
    /// 基于注视角度直接投影，并应用灵敏度放大。
    func projectGaze(faceAnchor: ARFaceAnchor, camera: ARCamera, viewSize: CGSize) -> CGPoint? {
        guard let (tanX, tanY) = extractRawGazeAngles(faceAnchor: faceAnchor, camera: camera) else {
            return nil
        }

        // 应用灵敏度放大，将 ±10-15° 的眼球旋转映射到完整 FOV
        let amplifiedTanX = tanX * sensitivityX
        let amplifiedTanY = tanY * sensitivityY

        // 在摄像头前方 1m 处按放大后的角度构造合成 3D 点
        let syntheticInCam = simd_float4(amplifiedTanX, amplifiedTanY, -1.0, 1.0)
        let syntheticInWorld = (camera.transform * syntheticInCam).xyz

        return camera.projectPoint(syntheticInWorld, orientation: .portrait, viewportSize: viewSize)
    }

    /// 使用校准仿射变换直接映射到屏幕坐标（跳过 projectPoint）
    func projectGazeWithCalibration(
        faceAnchor: ARFaceAnchor,
        camera: ARCamera,
        viewSize: CGSize,
        calibration: CalibrationData
    ) -> CGPoint? {
        guard let (tanX, tanY) = extractRawGazeAngles(faceAnchor: faceAnchor, camera: camera) else {
            return nil
        }

        let screenX = calibration.scaleX * tanX + calibration.offsetX
        let screenY = calibration.scaleY * tanY + calibration.offsetY

        return CGPoint(
            x: CGFloat(max(0, min(Float(viewSize.width), screenX))),
            y: CGFloat(max(0, min(Float(viewSize.height), screenY)))
        )
    }

    /// 提取原始注视角度值（tanX, tanY），用于校准采集和投影计算
    func extractRawGazeAngles(faceAnchor: ARFaceAnchor, camera: ARCamera) -> (Float, Float)? {
        let headTransform = faceAnchor.transform

        let leftGaze = faceAnchor.leftEyeTransform.columns.2.xyz
        let rightGaze = faceAnchor.rightEyeTransform.columns.2.xyz
        let avgGazeInFace = simd_normalize((leftGaze + rightGaze) / 2.0)

        let gazeWorld = simd_normalize((headTransform * simd_float4(avgGazeInFace, 0)).xyz)

        let camInverse = simd_inverse(camera.transform)
        let gazeInCam = (camInverse * simd_float4(gazeWorld, 0)).xyz

        guard gazeInCam.z > 0.01 else { return nil }

        return (gazeInCam.x / gazeInCam.z, gazeInCam.y / gazeInCam.z)
    }
}

// MARK: - SIMD Extensions

extension simd_float4 {
    var xyz: simd_float3 {
        simd_float3(x, y, z)
    }
}
