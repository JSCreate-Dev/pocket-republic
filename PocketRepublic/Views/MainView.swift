import SwiftUI

struct MainView: View {
    @EnvironmentObject private var game: Game
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                IslandView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Island", systemImage: "map.fill") }
            .tag(0)

            NavigationStack {
                PeopleView()
                    .navigationTitle("Citizens")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(RepublicTheme.cream, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem { Label("People", systemImage: "person.3.fill") }
            .tag(1)

            NavigationStack {
                GovernmentView()
                    .navigationTitle("Government")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(RepublicTheme.cream, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem { Label("Govern", systemImage: "building.columns.fill") }
            .tag(2)

            NavigationStack {
                GazetteView()
                    .navigationTitle("The Pocket Gazette")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(RepublicTheme.cream, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem { Label("Events", systemImage: "newspaper.fill") }
            .tag(3)
        }
        .tint(RepublicTheme.terracotta)
        .onChange(of: game.state.pending?.id) { _, pendingID in
            if pendingID != nil { tab = 0 }
        }
        .onChange(of: game.spotlight?.token) { _, token in
            if token != nil { tab = 0 }
        }
    }
}
