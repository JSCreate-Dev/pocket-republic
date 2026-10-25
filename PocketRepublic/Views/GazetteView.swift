import SwiftUI
import PocketRepublicCore

struct GazetteView: View {
    @EnvironmentObject private var game: Game
    @State private var expanded: Set<String> = []

    private var editions: [GazetteEdition] {
        EventGazette.editions(events: game.state.events, names: .from(game.state))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RepublicTheme.Space.lg) {
                if editions.isEmpty {
                    Text("The Pocket Gazette has not gone to press.")
                        .font(RepublicTheme.body())
                        .foregroundStyle(RepublicTheme.inkSoft)
                }
                ForEach(editions) { edition in
                    VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
                        Text(edition.masthead)
                            .font(RepublicTheme.heading(.title2))
                            .fixedSize(horizontal: false, vertical: true)
                        Rectangle()
                            .fill(RepublicTheme.terracotta)
                            .frame(height: 2)
                            .accessibilityHidden(true)
                        ForEach(edition.stories) { story in
                            storyCard(story)
                        }
                        if let routine = edition.routineLine {
                            Text(routine)
                                .font(RepublicTheme.body(.subheadline))
                                .foregroundStyle(RepublicTheme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(RepublicTheme.Space.md)
        }
        .background(RepublicTheme.cream)
        .foregroundStyle(RepublicTheme.ink)
    }

    private func storyCard(_ story: GazetteStory) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(bar(story.weight))
                .frame(width: 7)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
                HStack(alignment: .firstTextBaseline, spacing: RepublicTheme.Space.sm) {
                    if story.weight == .good {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(RepublicTheme.grass)
                            .accessibilityHidden(true)
                    }
                    Text(story.headline)
                        .font(story.weight == .crisis ? RepublicTheme.heading(.title3) : RepublicTheme.body(.body))
                        .fontWeight(story.weight == .good ? .regular : .semibold)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let because = story.because {
                    Text(because)
                        .font(RepublicTheme.body(.subheadline))
                        .foregroundStyle(RepublicTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                names(story)
                if let trend = story.trend {
                    Text(trend)
                        .font(RepublicTheme.body(.caption).weight(.bold))
                        .padding(.horizontal, RepublicTheme.Space.sm)
                        .padding(.vertical, RepublicTheme.Space.xs)
                        .background(RepublicTheme.alert.opacity(0.16), in: Capsule())
                }
                if canShow(story.location) {
                    Button {
                        game.showOnMap(story.location)
                    } label: {
                        Label("Show me", systemImage: "map.fill")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RepublicTheme.turquoise)
                    .foregroundStyle(RepublicTheme.ink)
                }
            }
            .padding(RepublicTheme.Space.md)
        }
        .background(RepublicTheme.sand.opacity(0.22), in: RoundedRectangle(cornerRadius: RepublicTheme.Space.chip, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: RepublicTheme.Space.chip, style: .continuous))
    }

    @ViewBuilder private func names(_ story: GazetteStory) -> some View {
        if let line = EventGazette.nameLine(story.names) {
            Button {
                if story.names.count > story.previewNames.count || story.names.count > 1 {
                    if expanded.contains(story.id) { expanded.remove(story.id) }
                    else { expanded.insert(story.id) }
                }
            } label: {
                Text(line)
                    .font(RepublicTheme.body(.subheadline))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .disabled(story.names.count < 2)
            if expanded.contains(story.id) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(story.names.enumerated()), id: \.offset) { _, name in
                        Text(name)
                            .font(RepublicTheme.body(.caption))
                    }
                }
            }
        }
    }

    private func bar(_ weight: StoryWeight) -> Color {
        switch weight {
        case .crisis: return RepublicTheme.terracotta
        case .decision: return RepublicTheme.turquoise
        case .bad: return RepublicTheme.alert
        case .good: return RepublicTheme.grass
        case .routine: return RepublicTheme.rock
        }
    }

    private func canShow(_ location: EventLocation) -> Bool {
        location.tile != nil || location.building != nil || location.district != nil
    }
}
