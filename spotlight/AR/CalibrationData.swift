import Foundation
import CoreGraphics

/// 校准结果：完整 2D 仿射变换，从原始注视角度 (tanX, tanY) 到屏幕坐标
///
/// screenX = ax * tanX + bx * tanY + cx
/// screenY = ay * tanX + by * tanY + cy
///
/// 使用完整仿射变换（而非独立 X/Y 回归）是因为 portrait 模式下
/// 摄像头坐标轴与屏幕坐标轴有 90° 旋转，tanX 实际影响 screenY，tanY 影响 screenX。
struct CalibrationData: Codable {
    var ax: Float, bx: Float, cx: Float  // screenX = ax*tanX + bx*tanY + cx
    var ay: Float, by: Float, cy: Float  // screenY = ay*tanX + by*tanY + cy

    /// 将原始 (tanX, tanY) 映射到屏幕坐标
    func mapToScreen(tanX: Float, tanY: Float, viewSize: CGSize) -> CGPoint {
        let sx = ax * tanX + bx * tanY + cx
        let sy = ay * tanX + by * tanY + cy
        return CGPoint(
            x: CGFloat(max(0, min(Float(viewSize.width), sx))),
            y: CGFloat(max(0, min(Float(viewSize.height), sy)))
        )
    }

    /// 从校准样本通过多元线性回归拟合 2D 仿射变换
    /// 每个样本: (rawTanX, rawTanY, screenX, screenY)
    static func compute(from samples: [(Float, Float, CGFloat, CGFloat)]) -> CalibrationData? {
        guard samples.count >= 3 else { return nil }

        let n = Float(samples.count)

        // 构建正规方程 A^T A x = A^T b（对 X 和 Y 分别求解）
        // 设计矩阵每行: [tanX, tanY, 1]
        // 目标向量: screenX 或 screenY
        var sumTx: Float = 0, sumTy: Float = 0
        var sumTx2: Float = 0, sumTy2: Float = 0, sumTxTy: Float = 0
        var sumTxSx: Float = 0, sumTySx: Float = 0, sumSx: Float = 0
        var sumTxSy: Float = 0, sumTySy: Float = 0, sumSy: Float = 0

        for (tx, ty, sx, sy) in samples {
            let fsx = Float(sx), fsy = Float(sy)
            sumTx += tx;       sumTy += ty
            sumTx2 += tx * tx; sumTy2 += ty * ty; sumTxTy += tx * ty
            sumTxSx += tx * fsx; sumTySx += ty * fsx; sumSx += fsx
            sumTxSy += tx * fsy; sumTySy += ty * fsy; sumSy += fsy
        }

        // 3x3 正规矩阵 (A^T A):
        // | sumTx2   sumTxTy  sumTx |
        // | sumTxTy  sumTy2   sumTy |
        // | sumTx    sumTy    n     |
        //
        // 用 Cramer 法则求解（3x3 足够小）
        let det = sumTx2 * (sumTy2 * n - sumTy * sumTy)
                - sumTxTy * (sumTxTy * n - sumTy * sumTx)
                + sumTx * (sumTxTy * sumTy - sumTy2 * sumTx)

        guard abs(det) > 1e-10 else { return nil }

        let invDet = 1.0 / det

        // 逆矩阵元素（伴随矩阵 / 行列式）
        let inv00 = (sumTy2 * n - sumTy * sumTy) * invDet
        let inv01 = (sumTx * sumTy - sumTxTy * n) * invDet
        let inv02 = (sumTxTy * sumTy - sumTy2 * sumTx) * invDet
        let inv10 = (sumTy * sumTx - sumTxTy * n) * invDet
        let inv11 = (sumTx2 * n - sumTx * sumTx) * invDet
        let inv12 = (sumTxTy * sumTx - sumTx2 * sumTy) * invDet
        let inv20 = (sumTxTy * sumTy - sumTy2 * sumTx) * invDet
        let inv21 = (sumTxTy * sumTx - sumTx2 * sumTy) * invDet
        let inv22 = (sumTx2 * sumTy2 - sumTxTy * sumTxTy) * invDet

        // 求解 screenX 系数: [ax, bx, cx] = inv * [sumTxSx, sumTySx, sumSx]
        let ax = inv00 * sumTxSx + inv01 * sumTySx + inv02 * sumSx
        let bx = inv10 * sumTxSx + inv11 * sumTySx + inv12 * sumSx
        let cx = inv20 * sumTxSx + inv21 * sumTySx + inv22 * sumSx

        // 求解 screenY 系数: [ay, by, cy] = inv * [sumTxSy, sumTySy, sumSy]
        let ay = inv00 * sumTxSy + inv01 * sumTySy + inv02 * sumSy
        let by = inv10 * sumTxSy + inv11 * sumTySy + inv12 * sumSy
        let cy = inv20 * sumTxSy + inv21 * sumTySy + inv22 * sumSy

        return CalibrationData(ax: ax, bx: bx, cx: cx, ay: ay, by: by, cy: cy)
    }

    // MARK: - 持久化

    private static let userDefaultsKey = "spotlight.calibrationData.v2"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
        // 清理旧版本
        UserDefaults.standard.removeObject(forKey: "spotlight.calibrationData")
    }

    static func load() -> CalibrationData? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(CalibrationData.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: "spotlight.calibrationData")
    }
}
