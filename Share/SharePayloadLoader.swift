import Foundation
import UIKit
import UniformTypeIdentifiers

@MainActor
final class SharePayloadLoader {
    private var task: Task<Void, Never>?
    private var completed = false
    private var partial = SharedSearchInput(text: "", wasTruncated: false)
    func cancel() { task?.cancel(); task = nil; completed = true }
    func load(_ items: [NSExtensionItem], completion: @escaping (SharedSearchInput) -> Void) {
        completed = false
        let providers = Array(items.flatMap { $0.attachments ?? [] }.prefix(12))
        let attributed = items.compactMap { $0.attributedContentText?.string }
        partial = SharedInputResolver.resolve(texts: attributed)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self, !self.completed else { return }
            self.completed = true
            self.task?.cancel()
            completion(self.partial)
        }
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            var selections: [String] = [], texts = attributed, urls: [String] = []
            for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                let value = await self.item(provider, type: UTType.propertyList.identifier)
                if let outer = value as? [String: Any],
                   let data = outer[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any] {
                    if let selection = data["selection"] as? String { selections.append(selection) }
                    if let url = data["url"] as? String { urls.append(url) }
                }
                self.partial = SharedInputResolver.resolve(selection: selections, texts: texts, urls: urls)
                if Task.isCancelled { return }
            }
            for provider in providers {
                // URL providers may advertise text too; don't mistake a URL for a passage.
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let value = await self.item(provider, type: UTType.url.identifier) {
                        if let url = value as? URL { urls.append(url.absoluteString) }
                        else if let text = self.string(value) { urls.append(text) }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let value = await self.item(provider, type: UTType.plainText.identifier), let text = self.string(value) { texts.append(text) }
                } else if provider.canLoadObject(ofClass: NSAttributedString.self) {
                    if let value = await self.item(provider, type: UTType.text.identifier), let text = self.string(value) { texts.append(text) }
                }
                self.partial = SharedInputResolver.resolve(selection: selections, texts: texts, urls: urls)
                if Task.isCancelled { return }
            }
            guard !self.completed else { return }
            self.completed = true
            completion(SharedInputResolver.resolve(selection: selections, texts: texts, urls: urls))
        }
    }
    private func string(_ item: NSSecureCoding) -> String? {
        if let text = item as? String { return text }
        if let text = item as? NSAttributedString { return text.string }
        if let data = item as? Data, data.count <= 1_000_000 { return String(data: data, encoding: .utf8) }
        return nil
    }
    private func item(_ provider: NSItemProvider, type: String) async -> NSSecureCoding? {
        await withCheckedContinuation { continuation in
            let gate = ProviderReply(continuation)
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in gate.finish(item) }
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { gate.finish(nil) }
        }
    }
}

private final class ProviderReply: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<NSSecureCoding?, Never>?
    init(_ continuation: CheckedContinuation<NSSecureCoding?, Never>) { self.continuation = continuation }
    func finish(_ value: NSSecureCoding?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
