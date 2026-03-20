import SwiftUI

struct HeatmapOverlayView: View {

    let heatmapManager: HeatmapManager

    var body: some View {
        if let image = heatmapManager.heatmapImage {
            Image(decorative: image, scale: 1.0)
                .resizable()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}
