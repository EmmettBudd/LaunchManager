import SwiftUI

/// A small inline "info" affordance for a form field whose purpose or expected
/// format isn't obvious from its label alone. Tapping it reveals an explanation
/// in a popover, on demand, instead of permanently occupying space with a caption.
struct InfoButton: View {
    let text: LocalizedStringKey

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(text)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            Text(text)
                .font(.callout)
                .padding(12)
                .frame(width: 260, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
