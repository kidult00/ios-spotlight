import Testing
import CoreGraphics
@testable import spotlight

struct SmoothingTests {

    @Test func emaConvergesToTarget() {
        var smoothed = CGPoint(x: 100, y: 100)
        let target = CGPoint(x: 300, y: 300)
        let alpha: CGFloat = 0.75 // 1 - smoothingFactor(0.25)

        for _ in 0..<30 {
            smoothed = CGPoint(
                x: smoothed.x + alpha * (target.x - smoothed.x),
                y: smoothed.y + alpha * (target.y - smoothed.y))
        }

        // 30 帧后应非常接近目标（误差 < 1pt）
        #expect(abs(smoothed.x - target.x) < 1)
        #expect(abs(smoothed.y - target.y) < 1)
    }

    @Test func emaSuppressesSingleSpike() {
        var smoothed = CGPoint(x: 200, y: 400)
        let alpha: CGFloat = 0.75

        // 一帧突然跳到 (0, 0)
        let spike = CGPoint(x: 0, y: 0)
        smoothed = CGPoint(
            x: smoothed.x + alpha * (spike.x - smoothed.x),
            y: smoothed.y + alpha * (spike.y - smoothed.y))

        // 平滑后不应跳到 (0,0)，应保留 25% 的旧值
        #expect(smoothed.x == 50)  // 200 * 0.25
        #expect(smoothed.y == 100) // 400 * 0.25
    }

    @Test func noSmoothingPassesThrough() {
        // smoothingFactor = 0 → alpha = 1.0 → 新值完全覆盖
        var smoothed = CGPoint(x: 100, y: 100)
        let target = CGPoint(x: 300, y: 300)
        let alpha: CGFloat = 1.0

        smoothed = CGPoint(
            x: smoothed.x + alpha * (target.x - smoothed.x),
            y: smoothed.y + alpha * (target.y - smoothed.y))

        #expect(smoothed.x == 300)
        #expect(smoothed.y == 300)
    }

    @Test func maxSmoothingIgnoresNewValue() {
        // smoothingFactor = 1.0 → alpha = 0.0 → 旧值完全保留
        var smoothed = CGPoint(x: 100, y: 100)
        let target = CGPoint(x: 300, y: 300)
        let alpha: CGFloat = 0.0

        smoothed = CGPoint(
            x: smoothed.x + alpha * (target.x - smoothed.x),
            y: smoothed.y + alpha * (target.y - smoothed.y))

        #expect(smoothed.x == 100)
        #expect(smoothed.y == 100)
    }
}
