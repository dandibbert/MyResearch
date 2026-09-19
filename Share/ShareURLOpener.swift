import UIKit

/// Self-signed compatibility adapter, NOT an Apple-guaranteed Share API.
/// No deprecated openURL:, private selectors, or UIApplication.shared.
@MainActor
final class ShareURLOpener {
    weak var owner: UIViewController?
    init(owner: UIViewController) { self.owner = owner }
    func open(_ url: URL, compatibility: Bool) async -> Bool {
        guard let owner else { return false }
        return await withCheckedContinuation { continuation in
            let reply = OpenReply(continuation)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                reply.finish(false)
            }
            @MainActor func bridge() {
                guard !reply.finished, compatibility else { reply.finish(false); return }
                var current: UIResponder? = owner
                var visited = Set<ObjectIdentifier>()
                while let responder = current, visited.insert(ObjectIdentifier(responder)).inserted {
                    if let application = responder as? UIApplication {
                        application.open(url, options: [:]) { accepted in
                            Task { @MainActor in reply.finish(accepted) }
                        }
                        return
                    }
                    current = responder.next
                }
                reply.finish(false)
            }
            if let context = owner.extensionContext {
                context.open(url) { accepted in
                    Task { @MainActor in
                        guard !reply.finished else { return }
                        if accepted { reply.finish(true) } else { bridge() }
                    }
                }
            } else { bridge() }
        }
    }
}

@MainActor
private final class OpenReply {
    private var continuation: CheckedContinuation<Bool, Never>?
    var finished: Bool { continuation == nil }
    init(_ continuation: CheckedContinuation<Bool, Never>) { self.continuation = continuation }
    func finish(_ accepted: Bool) {
        let pending = continuation
        continuation = nil
        pending?.resume(returning: accepted)
    }
}
