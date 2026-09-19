import SwiftUI
import UIKit

struct SystemShareSheet: UIViewControllerRepresentable {
    var text: String
    var includeURL = false
    func makeUIViewController(context: Context) -> UIActivityViewController {
        var items: [Any] = [text]
        if includeURL { items.insert(URL(string: "https://example.com/this-is-not-the-selected-text")!, at: 0) }
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
