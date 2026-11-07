import SwiftUI
import PocketRepublicCore

/// Details for one placed building.
///
/// The view sizes to its content. It does not present itself as a sheet or pin
/// itself to the bottom of the screen. Hosts put it in a column, a side pane, or
/// a sheet of their own. The island currently drops it in the controls rail.
struct BuildingInspectPanel: View {
    let inspection: BuildingInspection
    /// The core still reports construction with `InspectTone.calm`. The panel paints
    /// that row itself so a site does not look like a fault or like a finished building.
    var underConstruction: Bool = false
    var onClose: () -> Void
    var onSetMode: (OperatingMode) -> Void
    var onDemolish: () -> Void

    @State private var confirmDemolish = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(inspection.sections) { section in
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(section.rows) { row in
                        rowView(row)
                    }
                }
            }
            if !inspection.modeChoices.isEmpty {
                modePicker
                if underConstruction {
                    Text("Takes effect when it opens.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if inspection.canDemolish {
                Button(role: .destructive) {
                    confirmDemolish = true
                } label: {
                    Text(underConstruction ? "Cancel construction" : "Demolish")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .onChange(of: inspection.buildingID) { _, _ in
            confirmDemolish = false
        }
        .confirmationDialog(
            underConstruction ? "Cancel construction of this \(inspection.name)?" : "Demolish this \(inspection.name)?",
            isPresented: $confirmDemolish,
            titleVisibility: .visible
        ) {
            Button(underConstruction ? "Cancel construction" : "Demolish", role: .destructive, action: onDemolish)
            Button(underConstruction ? "Keep building" : "Cancel", role: .cancel) {}
        } message: {
            Text(underConstruction
                 ? "The build cost is not refunded. The plot is cleared."
                 : "This removes the building from the island.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(inspection.name)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Close building details")
        }
    }

    private var subtitle: String {
        if inspection.districtName.isEmpty { return inspection.typeName }
        return "\(inspection.typeName) · \(inspection.districtName)"
    }

    @ViewBuilder private func rowView(_ row: InspectRow) -> some View {
        switch row.tone {
        case .problem, .calm:
            if underConstruction && row.id == "status" {
                constructionStatus(row)
            } else {
                Text(row.value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(row.tone == .problem ? Color.orange : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("\(row.title), \(row.value)")
            }
        case .person:
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(row.value)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(.leading, 8)
            .accessibilityElement(children: .combine)
        case .plain:
            if row.title == "Progress", let fraction = progressFraction(row.value) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(row.title).foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text(row.value).fontWeight(.semibold)
                    }
                    ProgressView(value: fraction)
                        .tint(Color(red: 0.62, green: 0.42, blue: 0.18))
                    Text("Advances when you press Next Day.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .accessibilityElement(children: .combine)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(row.title)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Text(row.value)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.caption)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func constructionStatus(_ row: InspectRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Under construction")
                .font(.caption.weight(.bold))
            Text(stageLine(from: row.value))
                .font(.caption)
        }
        .foregroundStyle(Color(red: 0.45, green: 0.28, blue: 0.12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(red: 0.93, green: 0.82, blue: 0.62), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title), \(row.value)")
    }

    /// Core copy is "Under construction · Scaffold, 2 of 3 days". Show the stage half.
    private func stageLine(from value: String) -> String {
        guard let split = value.split(separator: "·", maxSplits: 1).last else { return value }
        return split.trimmingCharacters(in: .whitespaces)
    }

    private func progressFraction(_ value: String) -> Double? {
        let digits = value.filter(\.isNumber)
        guard let number = Double(digits) else { return nil }
        return min(1, max(0, number / 100))
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Operating mode")
                .font(.caption.weight(.semibold))
            ViewThatFits(in: .horizontal) {
                Picker("Operating mode", selection: modeBinding) {
                    ForEach(inspection.modeChoices) { choice in
                        Text(choice.label).tag(choice.mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 260)

                Picker("Operating mode", selection: modeBinding) {
                    ForEach(inspection.modeChoices) { choice in
                        Text(choice.label).tag(choice.mode.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var modeBinding: Binding<UInt8> {
        Binding(
            get: { inspection.selectedMode?.rawValue ?? OperatingMode.balanced.rawValue },
            set: { raw in
                guard let mode = OperatingMode(rawValue: raw), mode != inspection.selectedMode else { return }
                onSetMode(mode)
            }
        )
    }
}
