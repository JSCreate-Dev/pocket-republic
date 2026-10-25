import SwiftUI
import PocketRepublicCore

/// One inline navigation title. The old screen also used a form section named
/// "Government", and the large title drew on top of that header.
struct GovernmentView: View {
    @EnvironmentObject private var game: Game
    @State private var confirmNewCity = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RepublicTheme.Space.lg) {
                standing
                tax
                AgendaBoard(scrolls: false)
                save
            }
            .padding(RepublicTheme.Space.md)
        }
        .background(RepublicTheme.cream)
        .foregroundStyle(RepublicTheme.ink)
        .confirmationDialog("Start a new city?", isPresented: $confirmNewCity) {
            Button("Start New City", role: .destructive) { game.startNewCity() }
        } message: {
            Text("This replaces the spatial city save. Your earlier prototype save stays untouched.")
        }
    }

    private var standing: some View {
        HStack(alignment: .top, spacing: RepublicTheme.Space.md) {
            meter("Legitimacy", game.snapshot.legitimacy, highIsGood: true)
            meter("Corruption", game.snapshot.corruption, highIsGood: false)
        }
        .dioramaCard(fill: RepublicTheme.sand.opacity(0.35))
    }

    private func meter(_ title: String, _ value: Int32, highIsGood: Bool) -> some View {
        let worried = highIsGood ? value < 40 : value > 60
        return VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(RepublicTheme.body(.caption))
                .foregroundStyle(RepublicTheme.inkSoft)
            Text("\(value)%")
                .font(RepublicTheme.heading(.title2))
                .foregroundStyle(worried ? RepublicTheme.alert : RepublicTheme.fertile)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tax: some View {
        Stepper(value: Binding(
            get: { Int(game.state.policy.incomeTaxPercent) },
            set: { newValue in
                var next = game.state.policy
                next.incomeTaxPercent = Int32(newValue)
                game.send(.setPolicy(next))
            }
        ), in: 0...60, step: 5) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Income tax")
                    .font(RepublicTheme.heading(.headline))
                Text("\(game.state.policy.incomeTaxPercent)%")
                    .font(RepublicTheme.body(.title3))
                    .foregroundStyle(RepublicTheme.turquoise)
            }
        }
        .dioramaCard()
        .disabled(game.saveIssue != nil)
    }

    private var save: some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            if game.hasPrototypeSave {
                Text("Your earlier prototype save remains on this device. This city uses a separate save.")
                    .font(RepublicTheme.body(.caption))
                    .foregroundStyle(RepublicTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let issue = game.saveIssue {
                Text(issue)
                    .font(RepublicTheme.body(.subheadline))
                    .foregroundStyle(RepublicTheme.alert)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Start New City", role: .destructive) { confirmNewCity = true }
                .frame(minHeight: 44)
        }
        .dioramaCard()
    }
}
