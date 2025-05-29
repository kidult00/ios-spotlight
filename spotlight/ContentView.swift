import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @StateObject private var arTrackingManager = ARTrackingManager()

    var body: some View {
        ZStack {
            ARViewContainer(arTrackingManager: arTrackingManager)
                .edgesIgnoringSafeArea(.all)

            // Overlay for the gaze point
            if let gazePoint = arTrackingManager.gazeScreenPoint {
                Circle()
                    .fill(Color.red.opacity(0.7))
                    .frame(width: 20, height: 20)
                    .position(x: gazePoint.x, y: gazePoint.y)
            }

            // Existing UI elements
            VStack {
                Spacer()
                Text("AR Face Tracking Active")
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            arTrackingManager.startSession()
        }
        .onDisappear {
            arTrackingManager.pauseSession()
        }
    }
}

#Preview {
    ContentView()
}
