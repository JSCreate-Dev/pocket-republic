import SwiftUI
import PocketRepublicCore

/// Standing decree cards explain actual simulation effects and availability.
/// "Not now" only closes the card. It does not send the agenda's dismiss option,
/// which would remove the council offer.
struct DecreeBoard: View {
    var onShowIsland: () -> Void = {}
    var onReviewDecree: () -> Void = {}
    @EnvironmentObject private var game: Game
    @EnvironmentObject private var clock: DayClock
    @State private var policyDraft: GovernmentPolicyDraft?
    @State private var decreeGroup: GovernmentDecreeGroup = .all
    @State private var showAllLetters = false
    @State private var openDecree: String?
    @State private var confirmDecree: DecreeCardReading?
    @State private var decreeReceipt: String?
    @State private var decreeError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.lg) {
            today
            governmentFeedback
            council
            policies
            standing
            FactionCouncilPanel()
            decrees.id("government-decrees")
        }
        .foregroundStyle(RepublicTheme.ink)
        .sheet(item: $policyDraft, onDismiss: { clock.setModal("government-policy", presented: false) }) { draft in
            GovernmentPolicyEditor(draft: draft, onApply: { value in
                let applied = applyPolicy(draft, value: value)
                if applied { policyDraft = nil }
                return applied
            }, onCancel: { policyDraft = nil })
        }
        .onChange(of: policyDraft?.id) { _, id in clock.setModal("government-policy", presented: id != nil) }
        .onChange(of: confirmDecree?.id) { _, id in clock.setModal("government-decree", presented: id != nil) }
        .onChange(of: game.citySession) { _, _ in
            policyDraft = nil; confirmDecree = nil; decreeReceipt = nil; decreeError = nil
            clock.setModal("government-policy", presented: false)
            clock.setModal("government-decree", presented: false)
        }
        .onDisappear {
            policyDraft = nil; confirmDecree = nil
            clock.setModal("government-policy", presented: false)
            clock.setModal("government-decree", presented: false)
        }
        .confirmationDialog("Issue this decree?", isPresented: Binding(
            get: { confirmDecree != nil }, set: { if !$0 { confirmDecree = nil } }
        ), titleVisibility: .visible) {
            if let card = confirmDecree {
                Button("Issue · \(card.costLabel)") { issue(card) }
                Button("Cancel", role: .cancel) { confirmDecree = nil }
            }
        } message: {
            if let card = confirmDecree { Text("\(card.purpose)\n\(card.duration)\n\(card.caution)") }
        }
    }

    private var standing: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: RepublicTheme.Space.md) {
                meter("Public trust", game.snapshot.legitimacy, highIsGood: true)
                meter("Corruption", game.snapshot.corruption, highIsGood: false)
            }
            if let district = game.state.districts.max(by: { $0.unrest < $1.unrest }) {
                Text("Most unsettled district: \(district.name) · \(district.unrest)% unrest")
                    .font(.caption.weight(.semibold))
            }
            Text("Trust and corruption describe your government. Happiness describes daily life; faction approval records how groups feel about your decisions.")
                .font(.caption).foregroundStyle(RepublicTheme.inkSoft)
        }.dioramaCard(fill: RepublicTheme.sand.opacity(0.35))
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

    private var today: some View {
        let brief = GovernmentBrief(state: game.state)
        return VStack(alignment: .leading, spacing: 8) {
            Label("Today in your republic", systemImage: "sun.max.fill").font(.caption.weight(.semibold))
            Text(brief.title).font(RepublicTheme.heading(.title3))
            Text(brief.message).font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
            if let title = brief.suggestion, let spec = DecreeCatalogue.all.first(where: { $0.name == title }) {
                let reading = DecreeCardReading.make(spec: spec, state: game.state)
                Text("One option: \(reading.displayTitle) · \(reading.costLabel). \(reading.availability ?? "Available to review below.")")
                    .font(.caption.weight(.medium))
                Button("Review \(reading.displayTitle)") {
                    decreeGroup = .all; openDecree = title; onReviewDecree()
                }.frame(minHeight: 44).buttonStyle(.bordered)
            }
            Button(game.state.blocksAdvance ? "Resolve the decision on the island" : "Look at the island") { onShowIsland() }
                .frame(minHeight: 44).buttonStyle(.bordered)
        }.dioramaCard(fill: RepublicTheme.sand.opacity(0.35))
    }

    @ViewBuilder private var governmentFeedback: some View {
        if let error = decreeError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.subheadline).foregroundStyle(RepublicTheme.alert)
        }
        if let receipt = decreeReceipt {
            HStack(alignment: .top) {
                Label(receipt, systemImage: "checkmark.seal.fill")
                Spacer(minLength: 8)
                Button { decreeReceipt = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("Dismiss government result")
            }.font(.subheadline).dioramaCard(fill: RepublicTheme.grass.opacity(0.15))
        }
    }

    private var policies: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The everyday rules").font(RepublicTheme.heading(.title3))
            Text("These rates stay in place until you change them. Review one at a time; nothing changes while you try a value.")
                .font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
            ForEach(GovernmentPolicyField.allCases) { field in
                Button { policyDraft = GovernmentPolicyDraft(field: field, state: game.state) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: field.symbol).frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(field.title).font(.headline)
                            Text(field.label(field.value(in: game.state.policy))).font(.subheadline.weight(.semibold))
                            Text(field.explanation).font(.caption).foregroundStyle(RepublicTheme.inkSoft)
                            Text("Review a change").font(.caption.weight(.semibold)).foregroundStyle(RepublicTheme.terracotta)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(12).background(RepublicTheme.sand.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).disabled(game.saveIssue != nil || game.state.blocksAdvance)
            }
        }
    }

    private func applyPolicy(_ draft: GovernmentPolicyDraft, value: Int64) -> Bool {
        guard !game.state.blocksAdvance, game.saveIssue == nil,
              let next = draft.policy(value: value, in: game.state) else {
            decreeError = "The island or this rate changed. Close this review and open it again."
            return false
        }
        let before = game.state
        guard game.send(.setPolicy(next)) else {
            decreeError = game.saveIssue ?? game.feedback ?? "That change could not be applied."
            return false
        }
        let result = DecreeOutcomeReading.lines(before: before, after: game.state).joined(separator: "\n")
        decreeReceipt = "\(draft.field.title) updated.\n\(result)\nThe new rate applies at the next daily update."
        decreeError = nil
        return true
    }

    private var decrees: some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            Text("Decrees")
                .font(RepublicTheme.heading(.title3))
            Text("Shape life on your island. Some choices cost money once; others change taxes or pay until you change them again. Each decree has a \(game.state.config.effectiveDecreeCooldownDays)-day cooldown.")
                .font(RepublicTheme.body(.subheadline)).foregroundStyle(RepublicTheme.inkSoft)
            Text("▲ They approve · ▼ They object. More arrows mean a stronger reaction.")
                .font(RepublicTheme.body(.caption)).foregroundStyle(RepublicTheme.inkSoft)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GovernmentDecreeGroup.allCases) { group in
                        Button(group.rawValue) { decreeGroup = group; openDecree = nil }
                            .font(.caption.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 44)
                            .background(decreeGroup == group ? RepublicTheme.sand : RepublicTheme.cream,
                                        in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityAddTraits(decreeGroup == group ? .isSelected : [])
                    }
                }
            }
            ForEach(DecreeCatalogue.all.filter { decreeGroup.includes($0) }, id: \.name) { spec in
                decreeRow(spec)
            }
        }
    }

    @ViewBuilder private var council: some View {
        let items = game.state.agenda.filter { $0.kind != .decree }.sorted { lhs, rhs in
            func rank(_ item: AgendaItem) -> Int {
                AgendaSheetOrder.rank(tier: item.tier, isIslandEvent: item.islandEventID != nil,
                                      isDecree: item.kind == .decree, isOriginDilemma: item.originDilemma == true)
            }
            if rank(lhs) != rank(rhs) { return rank(lhs) < rank(rhs) }
            if lhs.expiresOnDay != rhs.expiresOnDay { return (lhs.expiresOnDay ?? Int32.max) < (rhs.expiresOnDay ?? Int32.max) }
            return lhs.id.raw < rhs.id.raw
        }
        if !items.isEmpty {
            Text("Letters that need your attention")
                .font(RepublicTheme.heading(.title3))
            Text("Requests have deadlines; ordinary advice can wait. Opening a letter does not accept it.")
                .font(.caption).foregroundStyle(RepublicTheme.inkSoft)
            ForEach(showAllLetters ? items : Array(items.prefix(1))) { item in councilCard(item) }
            if items.count > 1 {
                Button(showAllLetters ? "Show the next letter only" : "Read the other \(items.count - 1) letters") { showAllLetters.toggle() }
                    .frame(minHeight: 44).buttonStyle(.bordered)
            }
        }
    }

    private func decreeRow(_ spec: DecreeSpec) -> some View {
        let card = DecreeCardReading.make(spec: spec, state: game.state)
        let open = openDecree == spec.name
        return VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            Button {
                openDecree = open ? nil : spec.name
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: RepublicTheme.Space.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.displayTitle)
                            .font(RepublicTheme.heading(.headline))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(card.purpose)
                            .font(RepublicTheme.body(.caption)).foregroundStyle(RepublicTheme.inkSoft)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        Text(card.availability ?? "Ready to issue")
                            .font(RepublicTheme.body(.caption).weight(.semibold))
                            .foregroundStyle(card.canIssue ? RepublicTheme.fertile : RepublicTheme.inkSoft)
                        if let summary = card.chipSummary {
                            Text(summary)
                                .font(RepublicTheme.body(.caption))
                                .foregroundStyle(RepublicTheme.inkSoft)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: RepublicTheme.Space.sm)
                    Text(card.costLabel)
                        .font(RepublicTheme.heading(.subheadline))
                        .foregroundStyle(card.canAfford ? RepublicTheme.fertile : RepublicTheme.alert)
                }
                .padding(RepublicTheme.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RepublicTheme.sand.opacity(0.35), in: RoundedRectangle(cornerRadius: RepublicTheme.Space.chip, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(card.displayTitle), \(card.costLabel)")

            if open {
                decreeDetail(card)
            }
        }
    }

    private func decreeDetail(_ card: DecreeCardReading) -> some View {
        VStack(alignment: .leading, spacing: RepublicTheme.Space.sm) {
            Label(card.duration, systemImage: "clock")
                .font(RepublicTheme.body(.subheadline).weight(.semibold))
            Text(card.caution).font(RepublicTheme.body(.subheadline)).foregroundStyle(RepublicTheme.inkSoft)
            if let reason = card.availability {
                Text(reason).font(RepublicTheme.body(.subheadline)).foregroundStyle(RepublicTheme.alert)
            }
            Text("On your island right now").font(RepublicTheme.heading(.subheadline))
            ForEach(card.context, id: \.self) { line in
                Text(line).font(RepublicTheme.body(.subheadline)).fixedSize(horizontal: false, vertical: true)
            }
            Text("What will change").font(RepublicTheme.heading(.subheadline))
            if let shortfall = card.shortfall {
                Text("Need \(shortfall) more")
                    .font(RepublicTheme.body(.caption).weight(.semibold))
                    .foregroundStyle(RepublicTheme.alert)
            }
            if !card.chips.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), alignment: .leading)], alignment: .leading, spacing: RepublicTheme.Space.xs) {
                    ForEach(card.chips) { chip in
                        Text("\(chip.label) · \(chip.projection)")
                            .font(RepublicTheme.body(.caption).weight(.semibold))
                            .foregroundStyle(chip.pleased ? RepublicTheme.fertile : RepublicTheme.alert)
                    }
                }
            }
            ForEach(card.effects, id: \.self) { line in
                Text(line)
                    .font(RepublicTheme.body(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                confirmDecree = card
            } label: {
                Text("Issue · \(card.costLabel)")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(RepublicTheme.terracotta)
            .disabled(!card.canIssue || game.saveIssue != nil || game.state.blocksAdvance)
            Button("Not now") { openDecree = nil }
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .dioramaCard()
    }

    private func issue(_ card: DecreeCardReading) {
        guard game.saveIssue == nil, !game.state.blocksAdvance,
              let spec = DecreeCatalogue.all.first(where: { $0.name == card.title }) else {
            decreeError = "Finish the waiting decision or storage warning first."
            confirmDecree = nil
            return
        }
        let current = DecreeCardReading.make(spec: spec, state: game.state)
        guard current.canIssue else {
            decreeError = current.availability ?? "This decree can no longer be issued."
            confirmDecree = nil
            return
        }
        let day = game.state.day
        let before = game.state
        if game.send(.issueDecree(card.title)) {
            decreeError = nil
            let outcome = DecreeOutcomeReading.lines(before: before, after: game.state).joined(separator: "\n")
            decreeReceipt = "\(card.displayTitle) · Day \(day)\n\(outcome)\n\(card.duration)"
            openDecree = card.title
        } else {
            decreeError = game.saveIssue ?? game.feedback ?? "Could not issue the decree."
        }
        confirmDecree = nil
    }

    private func councilCard(_ item: AgendaItem) -> some View {
        AgendaChoiceCard(
            item: item,
            treasury: game.state.treasury,
            day: game.state.day,
            saveBlocked: game.saveIssue != nil,
            onResolve: { option in
                game.send(.resolveAgendaItem(item.id, option: option))
            }
        )
    }
}

/// One review screen for one lasting rate; the live policy changes only on Apply.
private struct GovernmentPolicyEditor: View {
    let draft: GovernmentPolicyDraft
    let onApply: (Int64) -> Bool
    let onCancel: () -> Void
    @EnvironmentObject private var game: Game
    @State private var value: Int
    @State private var error: String?

    init(draft: GovernmentPolicyDraft, onApply: @escaping (Int64) -> Bool, onCancel: @escaping () -> Void) {
        self.draft = draft; self.onApply = onApply; self.onCancel = onCancel
        _value = State(initialValue: max(0, Int(clamping: draft.original)))
    }

    private var upper: Int { draft.field == .publicPay ? max(20, Int(clamping: draft.original)) : max(80, Int(clamping: draft.original)) }
    private var reading: GovernmentPolicyReading { GovernmentPolicyReading(field: draft.field, value: Int64(value), state: game.state) }
    private var canApply: Bool {
        game.saveIssue == nil && !game.state.blocksAdvance && draft.policy(value: Int64(value), in: game.state) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(draft.field.explanation).font(.subheadline)
                    Text("In place now: \(draft.field.label(draft.original))").font(.caption).foregroundStyle(RepublicTheme.inkSoft)
                    Stepper(value: $value, in: 0...upper, step: draft.field == .publicPay ? 1 : 5) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Proposed rate").font(.caption)
                            Text(draft.field.label(Int64(value))).font(.title3.weight(.semibold))
                        }
                    }.padding(12).background(RepublicTheme.sand.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    Text(reading.headline).font(.headline)
                    Text(reading.detail).font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
                    if let warning = reading.warning {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline).foregroundStyle(RepublicTheme.alert)
                    }
                    Text("What to watch next").font(.headline)
                    Text(reading.watch).font(.subheadline)
                    Text("This sets a lasting rate. It does not award a decree’s faction-approval bonuses. Cancel leaves the existing rate in place.")
                        .font(.caption).foregroundStyle(RepublicTheme.inkSoft)
                    if let error { Text(error).font(.subheadline).foregroundStyle(RepublicTheme.alert) }
                    if let issue = game.saveIssue { Text(issue).font(.caption).foregroundStyle(RepublicTheme.alert) }
                    if game.state.blocksAdvance { Text("A crisis or election needs your decision first.").font(.caption).foregroundStyle(RepublicTheme.alert) }
                    Button("Apply \(draft.field.label(Int64(value)))") {
                        if !onApply(Int64(value)) { error = "This review is no longer current. Close it and review the rate again." }
                    }.frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.borderedProminent)
                        .tint(RepublicTheme.terracotta).disabled(!canApply)
                    Button("Keep the current rate", action: onCancel)
                        .frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.bordered)
                }.padding(16)
            }
            .background(RepublicTheme.cream).foregroundStyle(RepublicTheme.ink)
            .navigationTitle(draft.field.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) } }
        }.presentationDetents([.large])
    }
}

// MARK: - Government policy readers (no simulation mutation)
enum GovernmentPolicyField: String, CaseIterable, Identifiable {
    case household, business, publicPay
    var id: String { rawValue }
    var title: String {
        switch self { case .household: return "Household tax"; case .business: return "Business tax"; case .publicPay: return "Public workers’ pay" }
    }
    var symbol: String {
        switch self { case .household: return "person.2.fill"; case .business: return "storefront.fill"; case .publicPay: return "building.columns.fill" }
    }
    var explanation: String {
        switch self {
        case .household: return "Collected each day from the money residents hold after wages and food. A higher rate leaves them less to spend."
        case .business: return "Collected each day from cash held by standing private buildings, including homes. Higher rates leave workplaces less for wages and supplies."
        case .publicPay: return "The treasury pays clerks, nurses, teachers and police each day. This changes their pay, not private-sector wages."
        }
    }
    func value(in policy: Policy) -> Int64 {
        switch self { case .household: return Int64(policy.incomeTaxPercent); case .business: return Int64(policy.businessTaxPercent); case .publicPay: return policy.civicWage }
    }
    func label(_ value: Int64) -> String { self == .publicPay ? "$\(value) / worker / day" : "\(value)% each day" }
}

struct GovernmentPolicyDraft: Identifiable {
    let field: GovernmentPolicyField
    let original: Int64
    let seed: UInt64
    var id: String { field.rawValue }
    init(field: GovernmentPolicyField, state: RepublicState) {
        self.field = field; original = field.value(in: state.policy); seed = state.worldSeed
    }
    func policy(value: Int64, in state: RepublicState) -> Policy? {
        guard !state.blocksAdvance, state.worldSeed == seed, field.value(in: state.policy) == original,
              value >= 0, value != original else { return nil }
        var next = state.policy
        switch field {
        case .household: guard value <= 80 else { return nil }; next.incomeTaxPercent = Int32(value)
        case .business: guard value <= 80 else { return nil }; next.businessTaxPercent = Int32(value)
        case .publicPay: guard value <= max(20, original) else { return nil }; next.civicWage = value
        }
        return next
    }
}

struct GovernmentPolicyReading {
    let headline: String
    let detail: String
    let warning: String?
    let watch: String
    init(field: GovernmentPolicyField, value: Int64, state: RepublicState) {
        switch field {
        case .household:
            headline = "For each $100 held at collection, $\(value) goes to the treasury."
            detail = "It is a daily share of held money, not just new income. People earn and spend before collection; small payments round down."
            warning = value > Int64(state.config.taxPainPerPercentOver)
                ? "Above \(state.config.taxPainPerPercentOver)%, this rate adds tax pressure to wellbeing. Residents may also have less money for meals." : nil
            watch = "Watch household cash, hunger and happiness over the next few days. Lower tax does not create food or jobs."
        case .business:
            headline = "For each $100 held by a private building, $\(value) goes to the treasury."
            detail = "Collected after the day’s trading and wages. This is a share of remaining cash, not a tax on sales or profit."
            warning = value > Int64(state.policy.businessTaxPercent)
                ? "A larger share can squeeze the cash workplaces need for the next day’s wages and supplies." : nil
            watch = "Watch workplace funds, unpaid wages and market stock. Lower tax leaves cash in buildings; it does not pay a grant."
        case .publicPay:
            let staff = state.buildings.filter { $0.kind.isCivic && $0.isStanding(on: state.map) }.reduce(0) { $0 + $1.workers.count }
            let bill = value.multipliedReportingOverflow(by: Int64(staff))
            headline = bill.overflow ? "Payroll is too large to estimate." : "Scheduled public payroll: $\(bill.partialValue) per day for \(staff) workers."
            detail = "At current staffing. Hiring changes the bill; actual payments are limited by treasury funds. No money moves when you apply the rate."
            warning = value == 0 ? "A $0 rate stops public wages. These workers still need money for food."
                : bill.overflow || bill.partialValue > state.treasury ? "The treasury cannot cover one full day at this staffing and pay rate." : nil
            watch = "Watch treasury funds and public workers’ household cash. A higher rate does not automatically hire more people or expand service coverage."
        }
    }
}

enum GovernmentDecreeGroup: String, CaseIterable, Identifiable {
    case all = "All", food = "Food", money = "Money", community = "Community", order = "Trust & order"
    var id: String { rawValue }
    func includes(_ spec: DecreeSpec) -> Bool {
        if self == .all { return true }
        let e = spec.effect
        let group: GovernmentDecreeGroup
        if e.foodImport > 0 { group = .food }
        else if e.incomeTaxDelta != 0 || e.businessTaxDelta != 0 || e.civicWageDelta != 0 { group = .money }
        else if e.districtNeglectReset || (e.districtUnrest < 0 && e.legitimacy >= 0 && e.corruption == 0) { group = .community }
        else { group = .order }
        return group == self
    }
}

struct GovernmentBrief {
    let title: String
    let message: String
    let suggestion: String?
    init(state: RepublicState) {
        let hungry = state.citizens.filter { $0.alive && $0.daysHungry > 0 }.count
        let jobless = state.citizens.filter { $0.alive && $0.work == nil }.count
        if state.blocksAdvance {
            title = "Your island needs a decision"; message = "A crisis or election is waiting. Settle that first; the next day is held."; suggestion = nil
        } else if hungry > 0 {
            title = "\(hungry) neighbours need a meal"; message = "Check that their market has food, a road connection and customers who can afford a meal. Emergency food adds stock; it does not fix every cause of hunger."; suggestion = "Decree bread rationing"
        } else if state.treasury < 200 {
            title = "Keep an eye on the treasury"; message = "There is $\(state.treasury) available. Review daily public pay before making a lasting promise. Higher taxes bring a tradeoff for households and workplaces."; suggestion = nil
        } else if state.corruption >= 40 {
            title = "Trust needs some care"; message = "Corruption is \(state.corruption)%. An audit can reduce it, but it costs money and angers some officials."; suggestion = "Purge the graft registers"
        } else if let troubled = state.districts.max(by: { $0.unrest < $1.unrest }), troubled.unrest >= 40 {
            title = "Tension is rising in \(troubled.name)"; message = "A festival can ease unrest, but check food, work and services too. Calmer streets do not mean the underlying problem is solved."; suggestion = "Proclaim a market festival"
        } else if jobless > SettlementOutlook(state: state).openJobs {
            title = "People need somewhere to work"; message = "Let existing jobs fill automatically, then make room for the rest. A tax change cannot replace a missing workplace."; suggestion = nil
        } else {
            title = "Room to choose your next move"; message = "There is no crisis holding the day. Listen to requests, keep daily costs affordable and choose the changes that suit your island."; suggestion = nil
        }
    }
}

/// App-side reading of a decree. Keeps the card off `PocketRepublicCore`.
struct DecreeCardReading: Identifiable {
    struct Chip: Identifiable {
        var name: String
        var delta: Int32
        var arrows: String
        var projection: String
        var id: String { name }
        var pleased: Bool { delta > 0 }
        var label: String { "\(name) \(arrows)" }
    }

    var title: String
    var displayTitle: String {
        switch title {
        case "Decree bread rationing": return "Bring in emergency food"
        case "Proclaim a market festival": return "Hold a market festival"
        case "Purge the graft registers": return "Root out corruption"
        case "Raise the civic wage": return "Raise public workers’ pay"
        case "Declare a tax holiday": return "Ease household taxes"
        case "Levy an emergency rate": return "Raise household taxes"
        case "Impose a night curfew": return "Crack down on unrest"
        case "Order a public works season": return "Give neglected districts some care"
        default: return title
        }
    }
    var purpose: String
    var duration: String
    var caution: String
    var availability: String?
    var costLabel: String
    var shortfall: Int64?
    var canAfford: Bool
    var chips: [Chip]
    var effects: [String]
    var context: [String]
    var id: String { title }
    var canIssue: Bool { canAfford && availability == nil }
    var chipSummary: String? {
        let shown = chips.prefix(2).map(\.label)
        return shown.isEmpty ? nil : shown.joined(separator: " · ")
    }

    static func make(spec: DecreeSpec, state: RepublicState) -> DecreeCardReading {
        let pay = max(spec.cost, spec.effect.treasuryCost)
        let shortfall: Int64? = pay > state.treasury ? pay - state.treasury : nil
        let info = guide(spec, state: state)
        return DecreeCardReading(
            title: spec.name,
            purpose: info.purpose,
            duration: info.duration,
            caution: info.caution,
            availability: DecreeCatalogue.unavailableReason(for: spec, in: state),
            costLabel: pay == 0 ? "Free" : "$\(pay)",
            shortfall: shortfall,
            canAfford: shortfall == nil,
            chips: chips(factions: spec.effect.favorFactions, deltas: spec.effect.favorDeltas, state: state),
            effects: AgendaEffectCopy.lines(spec.effect).map { $0 == "Clears neglect in the district" ? "Clears neglect in every district" : $0 },
            context: context(spec, state: state)
        )
    }

    private static func guide(_ spec: DecreeSpec, state: RepublicState) -> (purpose: String, duration: String, caution: String) {
        let e = spec.effect
        if e.foodImport > 0 {
            return ("Buy \(e.foodImport) food for an open market.", "One-time stock delivery; no automatic refill.",
                    "Residents still need a reachable market and money to buy food. This does not create a permanent ration system.")
        }
        if e.civicWageDelta != 0 {
            return ("Raise the daily wage of civic workers.", "Lasting policy: $\(state.policy.civicWage) → $\(max(0, state.policy.civicWage + e.civicWageDelta)) per civic worker/day.",
                    "No upfront charge, but future civic payroll increases when workers are paid. Ensure the treasury can sustain it.")
        }
        if e.incomeTaxDelta != 0 {
            let next = max(0, min(80, state.policy.incomeTaxPercent + e.incomeTaxDelta))
            return (e.incomeTaxDelta < 0 ? "Leave more cash with households." : "Collect a larger share of household cash each day.",
                    "Lasting rate: \(state.policy.incomeTaxPercent)% → \(next)%. No automatic expiry.",
                    "The rate stays until changed again. Tax relief can reduce revenue; higher taxes can harm wellbeing. Faction effects apply immediately.")
        }
        if e.districtNeglectReset {
            return ("Clear accumulated neglect and ease district unrest.", "One-time action across all districts.",
                    "This does not place buildings or fund an ongoing construction program. Neglect can build up again.")
        }
        if e.corruption < 0 {
            return ("Reduce corruption and strengthen legitimacy.", "One-time political and government-meter changes.",
                    "Officials lose approval. This does not permanently stop future corruption.")
        }
        if e.legitimacy < 0 {
            return ("Suppress unrest across the island.", "One-time unrest and political changes.",
                    "Legitimacy falls and corruption rises. This currently changes unrest, not citizen movement or a timed night restriction.")
        }
        return ("Ease unrest with a public celebration.", "One-time unrest and faction-approval changes.",
                "This is not a recurring festival and does not directly refill markets or raise every citizen's happiness.")
    }

    private static func context(_ spec: DecreeSpec, state: RepublicState) -> [String] {
        let cost = max(spec.cost, spec.effect.treasuryCost)
        var lines = [cost <= state.treasury
            ? "Treasury after the upfront cost: $\(state.treasury - cost). Future wages and taxes are separate."
            : "Treasury $\(state.treasury); upfront shortfall $\(cost - state.treasury)."]
        let living = state.citizens.filter(\.alive)
        if spec.effect.foodImport > 0 {
            let hungry = living.filter { $0.daysHungry > 0 }.count
            let stock = state.buildings.filter { $0.kind == .market && $0.isStanding(on: state.map) }
                .reduce(Int64(0)) { $0 + Int64($1.foodStore) }
            lines.append("\(hungry) residents are hungry; standing markets hold \(stock) food. Delivery adds stock, not free meals or new market coverage.")
        }
        if spec.effect.civicWageDelta != 0 {
            let workers = living.filter { $0.work != nil && FactionKind.of($0.occupation) == .officials }.count
            lines.append("\(workers) currently employed civic workers: up to $\(Int64(workers) * spec.effect.civicWageDelta) additional payroll per paid day at today's staffing. Staffing and treasury can change.")
        }
        if spec.effect.districtUnrest != 0 {
            lines.append("Highest district unrest: \(state.districts.map(\.unrest).max() ?? 0)%. Lower unrest does not directly refill food stores, create jobs or raise every resident's happiness.")
        }
        if spec.effect.corruption < 0 {
            lines.append("Corruption now: \(state.corruption)%. This measure lowers it once; the underlying pressures can remain.")
        }
        if spec.effect.incomeTaxDelta != 0 {
            lines.append("Future tax receipts depend on actual taxable earnings. A three-point rate change is not a guaranteed dollar amount.")
        }
        return lines
    }

    private static func chips(factions: [FactionKind], deltas: [Int32], state: RepublicState) -> [Chip] {
        let count = min(factions.count, deltas.count)
        return (0..<count).compactMap { index in
            let delta = deltas[index]
            guard delta != 0 else { return nil }
            let current = state.factions.first { $0.kind == factions[index] }?.favor ?? 0
            let next = max(-100, min(100, current + delta))
            return Chip(name: factions[index].displayName, delta: delta, arrows: arrows(delta),
                        projection: "Approval \(current) → \(next)")
        }.sorted { lhs, rhs in
            if lhs.pleased != rhs.pleased { return lhs.pleased }
            return abs(lhs.delta) > abs(rhs.delta)
        }
    }

    private static func arrows(_ delta: Int32) -> String {
        let count: Int
        switch abs(delta) {
        case 0: return ""
        case 1...3: count = 1
        case 4...6: count = 2
        default: count = 3
        }
        return String(repeating: delta > 0 ? "▲" : "▼", count: count)
    }

}

/// Reports changes actually applied, including clamping, rather than promising
/// that a political decision already improved hunger, jobs or happiness.
enum DecreeOutcomeReading {
    static func lines(before: RepublicState, after: RepublicState) -> [String] {
        var result: [String] = []
        if before.treasury != after.treasury { result.append("Treasury: $\(before.treasury) → $\(after.treasury).") }
        if before.policy.incomeTaxPercent != after.policy.incomeTaxPercent {
            result.append("Household tax: \(before.policy.incomeTaxPercent)% → \(after.policy.incomeTaxPercent)%.")
        }
        if before.policy.businessTaxPercent != after.policy.businessTaxPercent {
            result.append("Business tax: \(before.policy.businessTaxPercent)% → \(after.policy.businessTaxPercent)%.")
        }
        if before.policy.civicWage != after.policy.civicWage {
            result.append("Public pay: $\(before.policy.civicWage) → $\(after.policy.civicWage) per worker each day.")
        }
        let foodBefore = before.buildings.reduce(Int64(0)) { $0 + Int64($1.foodStore) }
        let foodAfter = after.buildings.reduce(Int64(0)) { $0 + Int64($1.foodStore) }
        if foodAfter > foodBefore { result.append("\(foodAfter - foodBefore) food added to building stores. People still need access and money for meals.") }
        for faction in after.factions {
            guard let old = before.factions.first(where: { $0.kind == faction.kind }), old.favor != faction.favor else { continue }
            result.append("\(faction.kind.displayName) approval: \(old.favor) → \(faction.favor).")
        }
        if before.legitimacy != after.legitimacy { result.append("Public trust: \(before.legitimacy) → \(after.legitimacy).") }
        if before.corruption != after.corruption { result.append("Corruption: \(before.corruption) → \(after.corruption).") }
        if result.isEmpty { result.append("Decree issued. Its stated rules and cooldown now apply.") }
        return result
    }
}

/// The same authoritative nodes drive Govern and the island roadmap panel.
struct DevelopmentRoadmap: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        let nodes = DevelopmentTree.nodes(in: game.state)
        VStack(alignment: .leading, spacing: 12) {
            Label("Republic Roadmap", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                .font(RepublicTheme.heading(.title3))
            if nodes.isEmpty {
                Text("This existing city keeps its buildings available. Start a new city to follow the development roadmap.")
                    .font(.subheadline)
            } else {
                Text("Build a working settlement, then develop trade and community. Both paths stay open. Earned unlocks are permanent.")
                    .font(.caption).foregroundStyle(RepublicTheme.inkSoft)
                milestone(.workingTown, in: nodes)
                Label("Trade path", systemImage: "ferry.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(RepublicTheme.inkSoft)
                milestone(.harborCharter, in: nodes)
                    .padding(.leading, 12)
                Label("Community path", systemImage: "person.3.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(RepublicTheme.inkSoft)
                milestone(.communityCare, in: nodes)
                    .padding(.leading, 12)
                Image(systemName: "arrow.down").font(.caption).padding(.leading, 24)
                    .accessibilityHidden(true)
                milestone(.civicTown, in: nodes)
                    .padding(.leading, 12)
                Text("Homes, roads, farms, markets and workshops are always available. Residents find their own jobs.")
                    .font(.caption2).foregroundStyle(RepublicTheme.inkSoft)
            }
        }
        .dioramaCard()
    }

    @ViewBuilder private func milestone(_ id: DevelopmentUnlock, in nodes: [DevelopmentNode]) -> some View {
        if let node = nodes.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(BuildingSpriteCatalog.spec(for: id.building).imageName)
                        .resizable().scaledToFit().frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(id.title).font(.subheadline.weight(.bold))
                        Text(id.reward).font(.caption).foregroundStyle(RepublicTheme.inkSoft)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: node.unlocked ? "checkmark.seal.fill" : "lock.fill")
                        .foregroundStyle(node.unlocked ? RepublicTheme.fertile : RepublicTheme.inkSoft)
                        .accessibilityLabel(node.unlocked ? "Unlocked" : "Locked")
                }
                Text(node.unlocked ? "Unlocked · $\(node.grant) infrastructure grant awarded"
                     : "Reward: building access + $\(node.grant) infrastructure grant")
                    .font(.caption2.weight(.semibold))
                if !node.unlocked {
                    if let prerequisite = id.prerequisite, !node.prerequisiteMet {
                        Text("First earn \(prerequisite.title)")
                            .font(.caption.weight(.semibold)).foregroundStyle(RepublicTheme.terracotta)
                    }
                    ForEach(node.requirements.indices, id: \.self) { index in
                        let requirement = node.requirements[index]
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Image(systemName: requirement.met ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(requirement.met ? RepublicTheme.fertile : RepublicTheme.inkSoft)
                                Text(requirement.title)
                                Spacer(minLength: 4)
                                Text("\(requirement.current) / \(requirement.target)").monospacedDigit()
                            }
                            .font(.caption2)
                            ProgressView(value: Double(max(0, min(requirement.current, requirement.target))),
                                         total: Double(max(1, requirement.target)))
                                .tint(RepublicTheme.fertile)
                                .accessibilityLabel(requirement.title)
                                .accessibilityValue("\(requirement.current) of \(requirement.target)")
                        }
                    }
                    Text("Earned automatically when these conditions hold at the next daily update.")
                        .font(.caption2).foregroundStyle(RepublicTheme.inkSoft)
                }
            }
            .padding(10)
            .background(RepublicTheme.ink.opacity(node.unlocked ? 0.04 : 0.07),
                        in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// Political state is explained beside the powers that can change it.
private struct FactionCouncilPanel: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("People behind the politics", systemImage: "person.3.fill")
                .font(RepublicTheme.heading(.title3))
            Text("Neighbours group together around the work they do. Their approval shows how they feel about your decisions; happiness shows how life is going. A popular decision won’t fill an empty market.")
                .font(.subheadline).foregroundStyle(RepublicTheme.inkSoft)
            ForEach(FactionKind.allCases, id: \.rawValue) { kind in
                faction(kind)
            }
        }.dioramaCard()
    }

    private func faction(_ kind: FactionKind) -> some View {
        let report = FactionReport(kind: kind, state: game.state)
        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text(membership(kind)).font(.subheadline)
                if report.members == 0 {
                    Text("No current members. Political memory remains even when membership changes.")
                        .font(.caption).foregroundStyle(RepublicTheme.inkSoft)
                } else {
                    Text("Happiness \(report.happiness)% · Loyalty \(report.loyalty)%")
                        .font(.subheadline.monospacedDigit())
                    if let concern = report.concern {
                        Text("Last daily report: \(concernTitle(concern)) · \(report.concernPercent)% of members at that update.")
                            .font(.subheadline.weight(.semibold))
                        Text(advice(concern)).font(.subheadline)
                    } else {
                        Text(game.state.day == 0 ? "The first daily update will report shared grievances." : "No dominant concern recorded at the last daily update. Individuals may still have unmet needs.")
                            .font(.caption).foregroundStyle(RepublicTheme.inkSoft)
                    }
                }
                ForEach(report.demands) { demand in
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Active demand · see On your desk below", systemImage: "exclamationmark.bubble")
                        if let deadline = demand.expiresOnDay {
                            Text("Expires after Day \(deadline). Ignoring it costs \(demand.ignoreCost) approval when it lapses.")
                        }
                        Text(demand.causes.map { concernTitle($0.kind) }.joined(separator: " · "))
                    }.font(.caption).foregroundStyle(RepublicTheme.alert)
                }
                if !report.memory.isEmpty {
                    Text("Recent government memory").font(.caption.weight(.bold))
                    ForEach(report.memory.indices, id: \.self) { index in
                        let act = report.memory[index]
                        Text("Day \(act.day) · \(act.delta >= 0 ? "+" : "")\(act.delta) approval · \(act.detail == "decision" ? "Government decision" : act.detail)")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }.padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(kind.displayName) · \(report.members) residents").font(.headline)
                Text("Approval \(report.favor)\(report.demands.isEmpty ? "" : " · Demand waiting")")
                    .font(.caption.monospacedDigit()).foregroundStyle(RepublicTheme.inkSoft)
            }.padding(.vertical, 8)
        }
    }

    private func membership(_ kind: FactionKind) -> String {
        switch kind {
        case .labourers: return "Farmers, dockhands and artisans. These are the island's food, trade and workshop crews."
        case .merchants: return "Shopkeepers. They operate the markets that link producers with households."
        case .officials: return "Clerks, officers, teachers and nurses. Civic wages come from the treasury."
        case .landless: return "Residents with the unemployed occupation. The name is political: it does not necessarily mean they have no home."
        }
    }

    private func concernTitle(_ cause: CauseKind) -> String {
        switch cause {
        case .foodShortage: return "Hunger"
        case .unemployment: return "Not enough work"
        case .poverty: return "Low household cash"
        case .taxBurden: return "Tax pressure"
        case .corruption: return "Corruption"
        case .noMarketAccess: return "Market access"
        case .noClinicAccess: return "Clinic access"
        case .noPoliceAccess: return "Police access"
        case .treasuryDeficit: return "Treasury pressure"
        case .districtNeglect: return "District neglect"
        case .policyChange: return "Government policy"
        case .islandEvent: return "Island event"
        }
    }

    private func advice(_ cause: CauseKind) -> String {
        switch cause {
        case .foodShortage, .noMarketAccess:
            return "Check Food Access, market stock and residents' cash. Importing food helps stock; it cannot bridge a disconnected road or pay a household's bill."
        case .unemployment:
            return "Inspect vacancies and road access. Connected standing workplaces hire automatically on daily updates; sites cannot employ residents yet."
        case .poverty:
            return "Inspect residents' jobs and cash. A full treasury does not mean households can afford meals."
        case .taxBurden:
            return "Compare the lasting income-tax rate with payroll needs before cutting it. Relief can reduce future revenue."
        case .noClinicAccess, .noPoliceAccess:
            return "Check the service overlay, staffing and connected roads. A nearby foundation is not an operating service."
        case .corruption:
            return "Review corruption and the anti-graft decree. Its one-time improvement also costs money and Officials' approval."
        case .districtNeglect:
            return "Review district conditions and public works. Clearing neglect once does not build or staff new services."
        default: return "Read the demand's causes and each option's effects before making a promise. Addressing approval and addressing living conditions are different choices."
        }
    }
}
