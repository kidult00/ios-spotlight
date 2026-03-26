import Testing
import CoreGraphics
@testable import spotlight

struct CalibrationTests {

    @Test func computeFromSymmetricSamples() {
        // 对称样本：中心 + 四角
        let samples: [(Float, Float, CGFloat, CGFloat)] = [
            ( 0.00,  0.00, 200, 400),  // 中心
            ( 0.15, -0.10, 350, 200),  // 右上
            (-0.15,  0.10,  50, 600),  // 左下
            ( 0.15,  0.10, 350, 600),  // 右下
            (-0.15, -0.10,  50, 200),  // 左上
        ]

        let cal = CalibrationData.compute(from: samples)
        #expect(cal != nil)

        if let cal {
            // 中心点应映射到 (200, 400) 附近
            let centerX = cal.scaleX * 0.0 + cal.offsetX
            let centerY = cal.scaleY * 0.0 + cal.offsetY
            #expect(abs(centerX - 200) < 5)
            #expect(abs(centerY - 400) < 5)

            // scaleX 应为正（向右看 → tanX 增大 → screenX 增大）
            #expect(cal.scaleX > 0)
        }
    }

    @Test func computeRequiresMinimumSamples() {
        // 不足 2 个样本应返回 nil
        let single: [(Float, Float, CGFloat, CGFloat)] = [
            (0.0, 0.0, 200, 400),
        ]
        #expect(CalibrationData.compute(from: single) == nil)

        let empty: [(Float, Float, CGFloat, CGFloat)] = []
        #expect(CalibrationData.compute(from: empty) == nil)
    }

    @Test func twoSamplesCompute() {
        // 恰好 2 个样本也应能计算
        let samples: [(Float, Float, CGFloat, CGFloat)] = [
            (-0.1, -0.1, 100, 200),
            ( 0.1,  0.1, 300, 600),
        ]
        let cal = CalibrationData.compute(from: samples)
        #expect(cal != nil)

        if let cal {
            // 中间点 (0, 0) 应映射到 (200, 400)
            let midX = cal.scaleX * 0.0 + cal.offsetX
            let midY = cal.scaleY * 0.0 + cal.offsetY
            #expect(abs(midX - 200) < 1)
            #expect(abs(midY - 400) < 1)
        }
    }

    @Test func calibrationPersistence() {
        let data = CalibrationData(scaleX: 1000, scaleY: 2000, offsetX: 200, offsetY: 400)
        data.save()

        let loaded = CalibrationData.load()
        #expect(loaded != nil)
        #expect(loaded?.scaleX == 1000)
        #expect(loaded?.scaleY == 2000)
        #expect(loaded?.offsetX == 200)
        #expect(loaded?.offsetY == 400)

        // 清理
        CalibrationData.clear()
        #expect(CalibrationData.load() == nil)
    }
}
