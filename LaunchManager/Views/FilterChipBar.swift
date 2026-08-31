import SwiftUI

/// Conformance lets a filter enum drive a `FilterChipBar` — the chip's label and
/// optional icon come from the filter value itself, so call sites only need to
/// supply which options to show and where the current selection lives.
protocol FilterChipOption: Hashable {
    var chipTitle: LocalizedStringKey { get }
    var chipIcon: String? { get }
}

/// A horizontally scrolling row of rounded, accent-colored filter chips —
/// originally the Launch Agents scope filter, pulled out so other lists
/// (e.g. Services) can reuse the same look and selection behavior.
struct FilterChipBar<Filter: FilterChipOption>: View {
    let options: [Filter]
    @Binding var selection: Filter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    FilterChip(
                        title: option.chipTitle,
                        icon: option.chipIcon,
                        isSelected: selection == option
                    ) {
                        selection = option
                    }
                }
            }
        }
    }
}

private struct FilterChip: View {
    let title: LocalizedStringKey
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor.opacity(0.25) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
