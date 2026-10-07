import SwiftUI
import UIKit

struct CursorTemplateEditor: View {
    @Binding var text: String
    @Binding var selection: NSRange
    var placeholder: String
    var identifier: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 2)
                    .allowsHitTesting(false)
            }
            CursorTextView(text: $text, selection: $selection, identifier: identifier)
        }
        .frame(minHeight: 72, maxHeight: 132)
    }

    func inserting(_ token: String) -> (text: String, selection: NSRange) {
        let ns = text as NSString
        var range = selection
        if range.location == NSNotFound || range.location > ns.length || range.location + range.length > ns.length {
            range = NSRange(location: ns.length, length: 0)
        }
        let updated = ns.replacingCharacters(in: range, with: token)
        return (updated, NSRange(location: range.location + (token as NSString).length, length: 0))
    }
}

private struct CursorTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    var identifier: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.font = UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .regular)
        view.adjustsFontForContentSizeCategory = true
        view.autocapitalizationType = .none
        view.autocorrectionType = .no
        view.spellCheckingType = .no
        view.textContainerInset = UIEdgeInsets(top: 8, left: 2, bottom: 8, right: 2)
        view.textContainer.lineFragmentPadding = 0
        view.accessibilityIdentifier = identifier
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.markedTextRange == nil, view.text != text { view.text = text }
        let length = (view.text as NSString?)?.length ?? 0
        let safe = NSRange(location: min(selection.location, length), length: min(selection.length, max(0, length - min(selection.location, length))))
        if view.markedTextRange == nil, view.selectedRange != safe { view.selectedRange = safe }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CursorTextView
        init(parent: CursorTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            if parent.text != textView.text { parent.text = textView.text }
            if parent.selection != textView.selectedRange { parent.selection = textView.selectedRange }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            if parent.selection != textView.selectedRange { parent.selection = textView.selectedRange }
        }
    }
}
