import SwiftUI
import PocketRepublicCore

/// Details for one placed building.
///
/// The view sizes to its content. It does not present itself as a sheet or pin
/// itself to the bottom of the screen. Hosts put it in a column, a side pane, or
/// a sheet of their own. The island currently drops it in the controls rail.
struct BuildingInspectPanel: View {
    let inspection: BuildingInspection
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
            }
            if inspection.canDemolish {
                Button(role: .destructive) {
                    confirmDemolish = true
                } label: {
                    Text("Demolish")
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
        .confirmationDialog("Demolish this \(inspection.name)?", isPresented: $confirmDemolish, titleVisibility: .visible) {
            Button("Demolish", role: .destructive, action: onDemolish)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the building from the island.")
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
            Text(row.value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(row.tone == .problem ? Color.orange : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("\(row.title), \(row.value)")
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
