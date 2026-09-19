import SwiftUI
import UIKit

struct SearchField: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var identifier = "search-input"
    var submit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = "想搜索什么？"
        field.font = UIFont.preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.returnKeyType = .search
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.accessibilityIdentifier = identifier
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }
    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        // Never overwrite the IME's uncommitted marked text.
        if field.markedTextRange == nil, field.text != text { field.text = text }
        if focused, !field.isFirstResponder, field.window != nil {
            DispatchQueue.main.async { if context.coordinator.parent.focused { field.becomeFirstResponder() } }
        } else if !focused, field.isFirstResponder { field.resignFirstResponder() }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 180, height: 48)
    }
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SearchField
        init(parent: SearchField) { self.parent = parent }
        @objc func changed(_ field: UITextField) {
            guard field.markedTextRange == nil else { return }
            let value = String((field.text ?? "").prefix(4096))
            if parent.text != value { parent.text = value }
        }
        func textFieldDidChangeSelection(_ field: UITextField) { changed(field) }
        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.focused { parent.focused = true }
        }
        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.focused { parent.focused = false }
        }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            guard textField.markedTextRange == nil else { return false }
            parent.submit()
            return false
        }
    }
}
