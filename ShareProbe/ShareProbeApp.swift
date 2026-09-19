import SwiftUI

/// Simulator-only destination app, never embedded in the delivered IPA.
@main
struct ShareProbeApp: App {
    @State private var received = "Waiting"
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 20) {
                Text("External destination").font(.title)
                Text(received).accessibilityIdentifier("received-share-url")
            }.padding().onOpenURL { received = $0.absoluteString }
        }
    }
}
