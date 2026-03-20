import SwiftUI
import ARKit

struct ContentView: View {

    @State private var arTrackingManager = ARTrackingManager()
    @State private var heatmapManager = HeatmapManager(viewSize: UIScreen.main.bounds.size)
    @State private var showHeatmap = true

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
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
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
