import Foundation
import CoreImage
import CoreGraphics
import QuartzCore
import Observation

@Observable
class HeatmapManager {

    private(set) var heatmapImage: CGImage?

    let gridWidth: Int
    let gridHeight: Int

    private let cellSize: CGFloat
    private var rawGrid: [Float]
    private var maxValue: Float = 0
    private var lastImageUpdateTime: CFTimeInterval = 0
    private let imageUpdateInterval: CFTimeInterval = 0.1  // 10fps 刷新热图
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    init(viewSize: CGSize, cellSize: CGFloat = 10.0) {
        self.cellSize = cellSize
        self.gridWidth = Int(ceil(viewSize.width / cellSize))
        self.gridHeight = Int(ceil(viewSize.height / cellSize))
        self.rawGrid = [Float](repeating: 0, count: gridWidth * gridHeight)
    }

    /// 接收新的注视点，以高斯分布在网格中叠加权重
    func addGazePoint(_ point: CGPoint, viewSize: CGSize) {
        let cellX = Int(point.x / cellSize)
        let cellY = Int(point.y / cellSize)

        let radius = 8
        let sigma: Float = 4.0
        let twoSigmaSq = 2.0 * sigma * sigma

        for dy in -radius...radius {
            for dx in -radius...radius {
                let nx = cellX + dx
                let ny = cellY + dy
                guard nx >= 0, nx < gridWidth, ny >= 0, ny < gridHeight else { continue }

                let distSq = Float(dx * dx + dy * dy)
                let weight = exp(-distSq / twoSigmaSq)
                let idx = ny * gridWidth + nx
                rawGrid[idx] += weight
                maxValue = max(maxValue, rawGrid[idx])
            }
        }

        // 节流：仅按固定间隔生成热图图像（后台线程生成，避免阻塞主线程）
        let now = CACurrentMediaTime()
        if now - lastImageUpdateTime >= imageUpdateInterval {
            lastImageUpdateTime = now
            let gridSnapshot = rawGrid
            let maxSnapshot = maxValue
            let w = gridWidth
            let h = gridHeight
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self else { return }
                let image = self.renderHeatmapImage(grid: gridSnapshot, maxVal: maxSnapshot, gridW: w, gridH: h, size: viewSize)
                DispatchQueue.main.async {
                    self.heatmapImage = image
                }
            }
        }
    }

    /// 重置热图数据
    func reset() {
        rawGrid = [Float](repeating: 0, count: gridWidth * gridHeight)
        maxValue = 0
        heatmapImage = nil
    }

    // MARK: - 热图图像生成

    /// 线程安全的热图渲染：接受 grid 快照，可在后台线程调用
    private func renderHeatmapImage(grid: [Float], maxVal: Float, gridW: Int, gridH: Int, size: CGSize) -> CGImage? {
        guard maxVal > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = gridW * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: gridW * gridH * bytesPerPixel)

        for y in 0..<gridH {
            for x in 0..<gridW {
                let idx = y * gridW + x
                let normalized = grid[idx] / maxVal
                let (r, g, b, a) = colorForIntensity(normalized)
                let pixelIdx = idx * bytesPerPixel
                pixelData[pixelIdx] = r
                pixelData[pixelIdx + 1] = g
                pixelData[pixelIdx + 2] = b
                pixelData[pixelIdx + 3] = a
            }
        }

        guard let provider = CGDataProvider(data: Data(pixelData) as CFData),
              let smallImage = CGImage(
                  width: gridW,
                  height: gridH,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: bytesPerRow,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else { return nil }

        // CIImage 高斯模糊
        let ciImage = CIImage(cgImage: smallImage)
            .clampedToExtent()
            .applyingGaussianBlur(sigma: 5.0)
            .cropped(to: CIImage(cgImage: smallImage).extent)

        // 放大到屏幕尺寸
        let scaleX = size.width / CGFloat(gridW)
        let scaleY = size.height / CGFloat(gridH)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let outputRect = CGRect(origin: .zero, size: size)

        return ciContext.createCGImage(scaled, from: outputRect)
    }

    /// 将强度值 [0,1] 映射到 RGBA 颜色（premultiplied alpha）
    /// 颜色梯度：透明 → 蓝 → 青 → 绿 → 黄 → 红
    private func colorForIntensity(_ intensity: Float) -> (UInt8, UInt8, UInt8, UInt8) {
        guard intensity > 0.005 else { return (0, 0, 0, 0) }

        let alpha = min(1.0, intensity * 1.5)
        let r: Float, g: Float, b: Float

        switch intensity {
        case ..<0.25:
            let t = intensity / 0.25
            r = 0; g = t; b = 1
        case ..<0.5:
            let t = (intensity - 0.25) / 0.25
            r = 0; g = 1; b = 1 - t
        case ..<0.75:
            let t = (intensity - 0.5) / 0.25
            r = t; g = 1; b = 0
        default:
            let t = min(1.0, (intensity - 0.75) / 0.25)
            r = 1; g = 1 - t; b = 0
        }

        // Premultiplied alpha
        return (
            UInt8(r * alpha * 255),
            UInt8(g * alpha * 255),
            UInt8(b * alpha * 255),
            UInt8(alpha * 255)
        )
    }
}
