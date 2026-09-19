import UIKit
import SwiftUI

final class ShareViewController: UIViewController {
    private let model = ShareModel()
    private let loader = SharePayloadLoader()
    private var opener: ShareURLOpener?
    private var host: UIHostingController<AnyView>?
    private var finished = false
    override func viewDidLoad() {
        super.viewDidLoad()
        let opener = ShareURLOpener(owner: self)
        self.opener = opener
        model.openURL = { [weak opener] url, compatibility in
            await opener?.open(url, compatibility: compatibility) ?? false
        }
        model.done = { [weak self] in self?.finish() }
        let host = UIHostingController(rootView: AnyView(ShareScreen(model: model).tint(ResearchStyle.accent)))
        self.host = host
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor), host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        loader.load(extensionContext?.inputItems as? [NSExtensionItem] ?? []) { [weak self] in self?.model.receive($0) }
    }
    private func finish() {
        guard !finished else { return }
        finished = true
        loader.cancel()
        model.cancel()
        extensionContext?.completeRequest(returningItems: nil)
    }
}
