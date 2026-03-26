import Testing
import simd
@testable import spotlight

struct GazeConverterTests {

    @Test func defaultSensitivityCoversFullScreen() {
        // ARKit 最大眼球旋转约 ±15° → tan(15°) ≈ 0.268
        // 前置摄像头 FOV 一半约 30° → tan(30°) ≈ 0.577
        // 放大后的 tan 值应 >= 0.577 才能到达屏幕边缘
        let converter = GazePointConverter()
        let maxEyeTan: Float = 0.268

        let amplifiedX = maxEyeTan * converter.sensitivityX
        let amplifiedY = maxEyeTan * converter.sensitivityY
        let screenEdgeTan: Float = 0.577

        #expect(amplifiedX >= screenEdgeTan)
        #expect(amplifiedY >= screenEdgeTan)
    }

    @Test func sensitivityMultiplierAmplifies() {
        let converter = GazePointConverter()
        let rawTan: Float = 0.15

        let amplifiedX = rawTan * converter.sensitivityX
        let amplifiedY = rawTan * converter.sensitivityY

        #expect(amplifiedX > rawTan)
        #expect(amplifiedY > rawTan)
        #expect(abs(amplifiedX - 0.375) < 0.001)
        #expect(abs(amplifiedY - 0.45) < 0.001)
    }

    @Test func customSensitivityValues() {
        var converter = GazePointConverter()
        converter.sensitivityX = 4.0
        converter.sensitivityY = 5.0

        #expect(converter.sensitivityX == 4.0)
        #expect(converter.sensitivityY == 5.0)
        #expect(Float(0.1) * converter.sensitivityX == 0.4)
    }
}
