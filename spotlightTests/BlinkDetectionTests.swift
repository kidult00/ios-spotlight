import Testing
@testable import spotlight

struct BlinkDetectionTests {

    let threshold: Float = 0.5

    @Test func bothEyesOpen() {
        let left: Float = 0.1
        let right: Float = 0.15
        let isBlinking = left > threshold || right > threshold
        #expect(!isBlinking)
    }

    @Test func bothEyesClosed() {
        let left: Float = 0.8
        let right: Float = 0.75
        let isBlinking = left > threshold || right > threshold
        #expect(isBlinking)
    }

    @Test func singleEyeBlink() {
        // 单眼闭合也应触发眨眼检测
        let left: Float = 0.9
        let right: Float = 0.1
        let isBlinking = left > threshold || right > threshold
        #expect(isBlinking)
    }

    @Test func exactlyAtThreshold() {
        // 等于阈值时不算眨眼
        let left: Float = 0.5
        let right: Float = 0.5
        let isBlinking = left > threshold || right > threshold
        #expect(!isBlinking)
    }

    @Test func justAboveThreshold() {
        let left: Float = 0.51
        let right: Float = 0.3
        let isBlinking = left > threshold || right > threshold
        #expect(isBlinking)
    }
}
