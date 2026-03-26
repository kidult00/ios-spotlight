import Foundation
import CoreGraphics

/// 校准结果：从原始注视角度 (tanX, tanY) 到屏幕坐标的仿射变换参数
struct CalibrationData: Codable {
    var scaleX: Float
    var scaleY: Float
    var offsetX: Float
    var offsetY: Float

    /// 从校准样本点通过最小二乘法拟合仿射参数
    /// 每个样本: (rawTanX, rawTanY, screenX, screenY)
    static func compute(from samples: [(Float, Float, CGFloat, CGFloat)]) -> CalibrationData? {
        guard samples.count >= 2 else { return nil }

        let n = Float(samples.count)

        // 分别对 X 和 Y 做一元线性回归: screen = scale * tan + offset
        var sumTanX: Float = 0, sumScreenX: Float = 0
        var sumTanX2: Float = 0, sumTanXScreenX: Float = 0
        var sumTanY: Float = 0, sumScreenY: Float = 0
        var sumTanY2: Float = 0, sumTanYScreenY: Float = 0

        for (tx, ty, sx, sy) in samples {
            sumTanX += tx
            sumScreenX += Float(sx)
            sumTanX2 += tx * tx
            sumTanXScreenX += tx * Float(sx)

            sumTanY += ty
            sumScreenY += Float(sy)
            sumTanY2 += ty * ty
            sumTanYScreenY += ty * Float(sy)
        }

        // X 轴回归
        let denomX = n * sumTanX2 - sumTanX * sumTanX
        let scaleX: Float
        let offsetX: Float
        if abs(denomX) > Float.ulpOfOne {
            scaleX = (n * sumTanXScreenX - sumTanX * sumScreenX) / denomX
            offsetX = (sumScreenX - scaleX * sumTanX) / n
        } else {
            // tan 值无变化（所有样本角度相同），使用屏幕中心作为 offset
            scaleX = 0
            offsetX = sumScreenX / n
        }

        // Y 轴回归
        let denomY = n * sumTanY2 - sumTanY * sumTanY
        let scaleY: Float
        let offsetY: Float
        if abs(denomY) > Float.ulpOfOne {
            scaleY = (n * sumTanYScreenY - sumTanY * sumScreenY) / denomY
            offsetY = (sumScreenY - scaleY * sumTanY) / n
        } else {
            scaleY = 0
            offsetY = sumScreenY / n
        }

        return CalibrationData(scaleX: scaleX, scaleY: scaleY, offsetX: offsetX, offsetY: offsetY)
    }

    // MARK: - 持久化

    private static let userDefaultsKey = "spotlight.calibrationData"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    static func load() -> CalibrationData? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(CalibrationData.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
