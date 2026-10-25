import SwiftUI
import PocketRepublicCore

struct MainView: View {
    @EnvironmentObject var game: Game
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            dashboard.tabItem { Label("Island", systemImage: "leaf.fill") }.tag(0)
            citizens.tabItem { Label("Citizens", systemImage: "person.3.fill") }.tag(1)
            governance.tabItem { Label("Govern", systemImage: "building.columns.fill") }.tag(2)
            news.tabItem { Label("News", systemImage: "newspaper.fill") }.tag(3)
        }.tint(.mint)
        .alert(game.state.pending == "revolution" ? "Revolution!" : "Corruption Scandal", isPresented: Binding(get: { game.state.pending != nil }, set: { _ in })) {
            Button(game.state.pending == "revolution" ? "Negotiate ($600)" : "Investigate") { game.decide(0) }
            Button(game.state.pending == "revolution" ? "Deploy security" : "Cover it up", role: .destructive) { game.decide(1) }
        } message: { Text("A major political crisis requires your decision. The simulation is paused.") }
    }
    var dashboard: some View { NavigationStack { ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            Text("ISLA VERDE").font(.largeTitle.bold()).foregroundStyle(.mint)
            Text("Day \(game.state.day) • A republic in motion").foregroundStyle(.secondary)
            IslandView().frame(height: 245).clipShape(RoundedRectangle(cornerRadius: 18))
            HStack { metric("Citizens", "\(game.state.citizens.count)"); metric("Approval", "\(game.approval)%"); metric("Unrest", "\(game.state.unrest)%") }
            HStack { metric("Treasury", "$\(game.state.treasury)"); metric("Food", "\(game.state.food)"); metric("Corruption", "\(game.state.corruption)%") }
            Text("LATEST HEADLINE").font(.caption.bold()).foregroundStyle(.secondary)
            Text(game.state.news.first ?? "Quiet day").padding().frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            if let issue = game.saveIssue { Text(issue).foregroundStyle(.red).padding() }
            Button { game.advance() } label: { Label("Advance One Day", systemImage: "forward.fill").frame(maxWidth: .infinity).padding() }.buttonStyle(.borderedProminent).disabled(game.state.pending != nil || game.saveIssue != nil)
            Text("Offline catch-up: up to 3 days at 6 hours per simulated day. Major crises pause progression.").font(.caption).foregroundStyle(.secondary)
        }.padding()
    }.navigationTitle("Pocket Republic") } }
    func metric(_ label: String, _ value: String) -> some View { VStack(spacing: 5) { Text(value).font(.headline).minimumScaleFactor(0.6).lineLimit(1); Text(label).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(8).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10)) }
    var citizens: some View { NavigationStack { List(game.state.citizens) { c in NavigationLink { VStack(alignment: .leading, spacing: 14) { Text(c.name).font(.largeTitle.bold()); Text(c.occupation); Text("Happiness: \(c.happiness) / 100"); Text("Government loyalty: \(c.loyalty) / 100"); Text("Wealth: \(c.wealth)"); Text("Ambition: \(c.ambition)"); Text("Influence: \(c.influence)"); if c.criminal { Label("Black market activity", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }; Spacer() }.padding().navigationTitle("Citizen") } label: { HStack { Image(systemName: c.criminal ? "person.crop.circle.badge.exclamationmark" : "person.crop.circle").foregroundStyle(.mint); VStack(alignment: .leading) { Text(c.name); Text(c.occupation).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(c.loyalty)%").foregroundStyle(.secondary) } } }.navigationTitle("Citizens") } }
    var governance: some View { NavigationStack { Form { Section("Government policy") { Stepper("Tax rate: \(game.state.tax)%", value: $game.state.tax, in: 0...40, step: 5); Stepper("Public services: \(game.state.services)", value: $game.state.services, in: 0...100, step: 10); Stepper("Security budget: \(game.state.security)", value: $game.state.security, in: 0...100, step: 10); Button("Save Policies") { game.save() } }.disabled(game.saveIssue != nil); Section("Political conditions") { Text("Legitimacy: \(game.state.legitimacy)%"); Text("Unrest: \(game.state.unrest)%"); Text("Corruption: \(game.state.corruption)%") }; Section("Save") { if let issue = game.saveIssue { Text(issue).foregroundStyle(.red) }; Button("Restart Republic", role: .destructive) { game.reset() } } }.navigationTitle("Government") } }
    var news: some View { NavigationStack { List(Array(game.state.news.enumerated()), id: \.offset) { entry in Text(entry.element).padding(.vertical, 5) }.navigationTitle("Island News") } }
}
