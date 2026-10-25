import SwiftUI

@main struct PocketRepublicApp: App {
    @StateObject private var game = Game()
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(game)
                .preferredColorScheme(.light)
                .tint(RepublicTheme.terracotta)
        }
    }
}
