import SwiftUI
import ARKit

struct ContentView: View {

    @State private var arTrackingManager = ARTrackingManager()
    @State private var heatmapManager = HeatmapManager(viewSize: UIScreen.main.bounds.size)
    @State private var showHeatmap = true
    @State private var isCalibrating = false
    @State private var calibrationManager = CalibrationManager(viewSize: UIScreen.main.bounds.size)

    var body: some View {
        ZStack {
            ARViewContainer(session: arTrackingManager.session)
                .ignoresSafeArea()

            if showHeatmap {
                HeatmapOverlayView(heatmapManager: heatmapManager)
            }

            // 注视点指示器
            if let gazePoint = arTrackingManager.gazeScreenPoint {
                Circle()
                    .fill(Color.red.opacity(0.7))
                    .frame(width: 20, height: 20)
                    .position(x: gazePoint.x, y: gazePoint.y)
            }

            // 控制面板
            VStack {
                // 追踪状态
                if !arTrackingManager.isTracking {
                    Text("未检测到面部")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.top, 60)
                }

                Spacer()

                HStack(spacing: 20) {
                    Button {
                        showHeatmap.toggle()
                    } label: {
                        Image(systemName: showHeatmap ? "eye.fill" : "eye.slash.fill")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Button {
                        heatmapManager.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Button {
                        calibrationManager = CalibrationManager(viewSize: UIScreen.main.bounds.size)
                        calibrationManager.startCalibration()
                        arTrackingManager.calibrationManager = calibrationManager
                        isCalibrating = true
                    } label: {
                        Image(systemName: arTrackingManager.calibrationData != nil ? "scope" : "scope")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(arTrackingManager.calibrationData != nil
                                ? AnyShapeStyle(.thinMaterial)
                                : AnyShapeStyle(.ultraThinMaterial))
                            .clipShape(Circle())
                            .overlay(
                                arTrackingManager.calibrationData != nil
                                    ? Circle().stroke(Color.green, lineWidth: 2)
                                    : nil
                            )
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .overlay {
            if isCalibrating {
                CalibrationView(
                    calibrationManager: calibrationManager,
                    onComplete: { data in
                        arTrackingManager.calibrationData = data
                        arTrackingManager.calibrationManager = nil
                        isCalibrating = false
                    },
                    onCancel: {
                        arTrackingManager.calibrationManager = nil
                        isCalibrating = false
                    }
                )
            }
        }
        .onAppear {
            arTrackingManager.calibrationData = CalibrationData.load()
            arTrackingManager.startSession()
        }
        .onDisappear {
            arTrackingManager.pauseSession()
        }
        .onChange(of: arTrackingManager.gazeScreenPoint) { _, newPoint in
            if let point = newPoint {
                heatmapManager.addGazePoint(point, viewSize: UIScreen.main.bounds.size)
            }
        }
    }
}

#Preview {
    ContentView()
}
