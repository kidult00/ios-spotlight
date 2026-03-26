import Testing
import CoreGraphics
@testable import spotlight

struct CalibrationTests {

    @Test func computeFromSymmetricSamples() {
        // 模拟 portrait 模式：tanX 影响 screenY, tanY 影响 screenX
        // 这正是完整仿射变换能处理而独立回归不能处理的情况
        let samples: [(Float, Float, CGFloat, CGFloat)] = [
            ( 0.00,  0.00, 200, 400),  // 中心
            ( 0.10, -0.15, 200, 200),  // 上中（tanX↑→screenY↓, tanY 变化大→screenX 不变）
            (-0.10,  0.15, 200, 600),  // 下中
            ( 0.00,  0.15, 350, 400),  // 右中（tanY↑→screenX↑）
            ( 0.00, -0.15,  50, 400),  // 左中
        ]

        let cal = CalibrationData.compute(from: samples)
        #expect(cal != nil)

        if let cal {
            // 中心点应映射到 (200, 400) 附近
            let center = cal.mapToScreen(tanX: 0, tanY: 0, viewSize: CGSize(width: 400, height: 800))
            #expect(abs(center.x - 200) < 10)
            #expect(abs(center.y - 400) < 10)
        }
    }

    @Test func computeHandlesAxisRotation() {
        // 纯轴旋转：tanX → screenY, tanY → screenX（portrait 模式典型情况）
        let samples: [(Float, Float, CGFloat, CGFloat)] = [
            ( 0.0,  0.0, 200, 400),
            ( 0.1,  0.0, 200, 200),  // tanX 增大 → screenY 减小
            (-0.1,  0.0, 200, 600),  // tanX 减小 → screenY 增大
            ( 0.0,  0.1, 350, 400),  // tanY 增大 → screenX 增大
            ( 0.0, -0.1,  50, 400),  // tanY 减小 → screenX 减小
        ]

        let cal = CalibrationData.compute(from: samples)
        #expect(cal != nil)

        if let cal {
            // tanX 应主要影响 screenY（ay 应为负数，大绝对值）
            #expect(abs(cal.ay) > abs(cal.ax))
            // tanY 应主要影响 screenX（bx 应为正数，大绝对值）
            #expect(abs(cal.bx) > abs(cal.by))
        }
    }

    @Test func computeRequiresMinimumSamples() {
        // 需要至少 3 个样本（3 个未知数）
        let two: [(Float, Float, CGFloat, CGFloat)] = [
            (0.0, 0.0, 200, 400),
            (0.1, 0.1, 300, 600),
        ]
        #expect(CalibrationData.compute(from: two) == nil)

        let single: [(Float, Float, CGFloat, CGFloat)] = [
            (0.0, 0.0, 200, 400),
        ]
        #expect(CalibrationData.compute(from: single) == nil)

        let empty: [(Float, Float, CGFloat, CGFloat)] = []
        #expect(CalibrationData.compute(from: empty) == nil)
    }

    @Test func threeSamplesCompute() {
        // 恰好 3 个样本（最小可解）
        let samples: [(Float, Float, CGFloat, CGFloat)] = [
            ( 0.0,  0.0, 200, 400),
            ( 0.1,  0.0, 200, 200),
            ( 0.0,  0.1, 350, 400),
        ]
        let cal = CalibrationData.compute(from: samples)
        #expect(cal != nil)
    }

    @Test func mapToScreenClampsToViewport() {
        let cal = CalibrationData(ax: 0, bx: 5000, cx: 200, ay: -5000, by: 0, cy: 400)
        let viewSize = CGSize(width: 400, height: 800)

        // 极端 tanY 应被钳位到屏幕边界
        let farRight = cal.mapToScreen(tanX: 0, tanY: 1.0, viewSize: viewSize)
        #expect(farRight.x == 400)  // 钳位到宽度

        let farLeft = cal.mapToScreen(tanX: 0, tanY: -1.0, viewSize: viewSize)
        #expect(farLeft.x == 0)     // 钳位到 0
    }

    @Test func calibrationPersistence() {
        let data = CalibrationData(ax: 100, bx: 1500, cx: 200, ay: -2000, by: 50, cy: 400)
        data.save()

        let loaded = CalibrationData.load()
        #expect(loaded != nil)
        #expect(loaded?.ax == 100)
        #expect(loaded?.bx == 1500)
        #expect(loaded?.cx == 200)
        #expect(loaded?.ay == -2000)
        #expect(loaded?.by == 50)
        #expect(loaded?.cy == 400)

        // 清理
        CalibrationData.clear()
        #expect(CalibrationData.load() == nil)
    }
}
