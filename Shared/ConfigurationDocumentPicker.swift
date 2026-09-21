import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Uses UIKit's document picker rather than SwiftUI's fileImporter so file-provider
/// metadata quirks do not make visible JSON files untappable.
struct ConfigurationDocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Some Files providers expose .json files as generic text/data instead of
        // public.json. Accept those containers here and validate the actual bytes later.
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.json, .plainText, .data],
            asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL?) -> Void
        init(onPick: @escaping (URL?) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}

enum ConfigurationImport {
    static func load(_ url: URL) throws -> Configuration {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        if values.isRegularFile == false {
            throw ResearchError("请选择一个 JSON 配置文件。")
        }
        if let size = values.fileSize, size > 2_000_000 {
            throw ResearchError("配置文件不能超过 2 MB。")
        }

        var coordinatedError: NSError?
        var readingError: Error?
        var data: Data?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatedError) { readableURL in
            do { data = try Data(contentsOf: readableURL, options: .mappedIfSafe) }
            catch { readingError = error }
        }

        if let readingError { throw readingError }
        if let coordinatedError { throw coordinatedError }
        guard let data else { throw ResearchError("无法读取所选文件。") }
        return try ConfigurationCodec.decode(data)
    }
}
