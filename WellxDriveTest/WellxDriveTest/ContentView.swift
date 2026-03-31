import SwiftUI

struct ContentView: View {
    @StateObject private var tripManager = TripManager()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if tripManager.showSummary, let data = tripManager.tripData {
                TripSummaryView(tripData: data) {
                    tripManager.showSummary = false
                }
            } else {
                TripView(tripManager: tripManager)
            }
        }
        .preferredColorScheme(.light)
    }
}
