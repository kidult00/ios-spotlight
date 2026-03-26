import SwiftUI

struct CalibrationView: View {

    let calibrationManager: CalibrationManager
    let onComplete: (CalibrationData) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            if case .collecting(let index) = calibrationManager.state {
                let target = calibrationManager.targetPoints[index]

                // 目标点：白色脉动圆
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                            .frame(width: 40, height: 40)
                    )
                    .position(x: target.x, y: target.y)

                // 采集进度环
                Circle()
                    .trim(from: 0, to: CGFloat(calibrationManager.currentPointProgress))
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .position(x: target.x, y: target.y)

                // 提示文字
                VStack(spacing: 8) {
                    Text("请注视白色圆点")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(index + 1) / \(calibrationManager.targetPoints.count)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .position(x: UIScreen.main.bounds.width / 2, y: 80)
            }

            if case .completed = calibrationManager.state {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("校准完成")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .onAppear {
                    if let result = calibrationManager.calibrationResult {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onComplete(result)
                        }
                    }
                }
            }

            if case .failed = calibrationManager.state {
                VStack(spacing: 16) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("校准失败，请重试")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onCancel()
                    }
                }
            }

            // 取消按钮
            VStack {
                Spacer()
                Button {
                    calibrationManager.cancel()
                    onCancel()
                } label: {
                    Text("取消")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                }
                .padding(.bottom, 50)
            }
        }
    }
}
