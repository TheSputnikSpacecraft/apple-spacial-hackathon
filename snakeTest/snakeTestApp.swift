import SwiftUI
import RealityKit
import ARKit

@main
struct MyApp: App {
    private let session = ARKitSession()
    private let provider = HandTrackingProvider()
    private let rootEntity = Entity()

    var body: some SwiftUI.Scene {
        ImmersiveSpace {
            ContentView()
        }
        .upperLimbVisibility(.visible)
    }
}
