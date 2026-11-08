import SwiftUI

@main struct PocketRepublicApp: App {
    @StateObject private var game = Game()
    @StateObject private var clock = DayClock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(game)
                .environmentObject(clock)
                .preferredColorScheme(.dark)
                .onAppear {
                    clock.attach(game)
                    clock.note(game)
                }
                .onChange(of: scenePhase) { _, phase in
                    clock.setSceneActive(phase == .active)
                }
        }
    }
}
