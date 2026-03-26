import Foundation
import CoreGraphics
import Observation

@Observable
class CalibrationManager {

    enum State: Equatable {
        case idle
        case collecting(pointIndex: Int)
        case completed
        case failed
    }

    private(set) var state: State = .idle
    private(set) var calibrationResult: CalibrationData?

    /// 9 个校准目标点（屏幕坐标）
    let targetPoints: [CGPoint]

    /// 每个点采集的原始 (tanX, tanY) 样本
    private var collectedSamples: [[(Float, Float)]] = []

    /// 每个点采集帧数（1.5s × 30fps = 45）
    let framesPerPoint = 45
    private(set) var currentFrameCount = 0

    init(viewSize: CGSize) {
        // 9 点网格，10% 边距
        let marginX = viewSize.width * 0.1
        let marginY = viewSize.height * 0.1
        let midX = viewSize.width / 2
        let midY = viewSize.height / 2
        let right = viewSize.width - marginX
        let bottom = viewSize.height - marginY

        targetPoints = [
            CGPoint(x: marginX, y: marginY),     // 左上
            CGPoint(x: midX, y: marginY),         // 上中
            CGPoint(x: right, y: marginY),        // 右上
            CGPoint(x: marginX, y: midY),         // 左中
            CGPoint(x: midX, y: midY),            // 中心
            CGPoint(x: right, y: midY),           // 右中
            CGPoint(x: marginX, y: bottom),       // 左下
            CGPoint(x: midX, y: bottom),          // 下中
            CGPoint(x: right, y: bottom),         // 右下
        ]
    }

    func startCalibration() {
        collectedSamples = Array(repeating: [], count: targetPoints.count)
        currentFrameCount = 0
        calibrationResult = nil
        state = .collecting(pointIndex: 0)
    }

    /// 由 ARTrackingManager 在每帧调用，传入原始 tanX/tanY
    func addSample(tanX: Float, tanY: Float) {
        guard case .collecting(let index) = state else { return }

        collectedSamples[index].append((tanX, tanY))
        currentFrameCount += 1

        if currentFrameCount >= framesPerPoint {
            // 当前点采集完成，移到下一个
            let nextIndex = index + 1
            if nextIndex < targetPoints.count {
                currentFrameCount = 0
                state = .collecting(pointIndex: nextIndex)
            } else {
                // 所有点采集完成，计算校准
                computeCalibration()
            }
        }
    }

    func cancel() {
        state = .idle
        collectedSamples = []
        currentFrameCount = 0
    }

    /// 当前校准点的采集进度 (0.0 ~ 1.0)
    var currentPointProgress: Float {
        Float(currentFrameCount) / Float(framesPerPoint)
    }

    private func computeCalibration() {
        // 对每个校准点，取中间 60% 的样本（去掉头尾各 20% 的过渡帧）
        var allSamples: [(Float, Float, CGFloat, CGFloat)] = []

        for (i, samples) in collectedSamples.enumerated() {
            let count = samples.count
            guard count >= 5 else { continue }

            let trimStart = count / 5
            let trimEnd = count - count / 5
            let trimmed = Array(samples[trimStart..<trimEnd])

            // 取均值作为该点的代表值
            let avgTanX = trimmed.map(\.0).reduce(0, +) / Float(trimmed.count)
            let avgTanY = trimmed.map(\.1).reduce(0, +) / Float(trimmed.count)

            allSamples.append((avgTanX, avgTanY, targetPoints[i].x, targetPoints[i].y))
        }

        if let result = CalibrationData.compute(from: allSamples) {
            calibrationResult = result
            result.save()
            state = .completed
        } else {
            state = .failed
        }
    }
}
