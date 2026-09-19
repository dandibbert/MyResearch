import SwiftUI
import UIKit

struct BrowserDestination: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

@MainActor
final class ShareModel: ObservableObject {
    @Published var query = ""
    @Published var configuration = Configuration.initial
    @Published var error: String?
    @Published var notice = ""
    @Published var synchronization = "内置来源"
    @Published var synchronized = false
    @Published var loading = true
    @Published var opening = false
    @Published var browser: BrowserDestination?
    @Published var failedURL: URL?
    @Published var failedWebURL: URL?
    @Published var compatibility = UserDefaults.standard.object(forKey: "compatibility-opening") as? Bool ?? true {
        didSet { UserDefaults.standard.set(compatibility, forKey: "compatibility-opening") }
    }
    var openURL: ((URL, Bool) async -> Bool)?
    var done: (() -> Void)?
    private var openingTask: Task<Void, Never>?
    var intent: SearchIntent { SearchRouter.intent(for: query, configuration: configuration) }
    var currentTarget: SearchTarget? {
        configuration.enabledTargets.first { $0.id == intent.targetID } ?? configuration.defaultTarget
    }
    init() { reloadConfiguration() }
    func reloadConfiguration() {
        synchronized = false
        synchronization = "内置来源"
        if let data = UserDefaults.standard.data(forKey: "share-configuration"),
           let decoded = try? ConfigurationCodec.decode(data) {
            configuration = decoded
            synchronization = "本地导入的来源"
        }
        do {
            if let snapshot = try SharedConfiguration.read() {
                configuration = snapshot.configuration
                synchronization = "已同步主 App · \(configuration.enabledTargets.count) 个来源"
                synchronized = true
            } else { synchronization += " · 可在主 App 继续" }
        } catch { synchronization += " · 共享权限不可用" }
    }
    func importConfiguration(_ value: Configuration) throws {
        UserDefaults.standard.set(try ConfigurationCodec.encode(value), forKey: "share-configuration")
        configuration = value
        synchronized = false
        synchronization = "本地导入 · \(value.enabledTargets.count) 个来源"
    }
    func receive(_ value: SharedSearchInput) {
        guard loading else { return }
        query = value.text
        loading = false
        if value.wasTruncated { notice = "分享内容较长，已保留前 4096 字；可编辑后搜索。" }
        else if query.isEmpty { notice = "未收到可搜索的文字，请粘贴或输入。" }
    }
    func cancel() { openingTask?.cancel(); openingTask = nil }
    func search(_ text: String, target: SearchTarget?) {
        guard !opening else { return }
        guard let target else { error = "没有启用的搜索来源，可在主 App 中添加。"; return }
        do {
            let primary = try TemplateEngine.url(template: target.template, query: text)
            let fallback = target.fallbackTemplate.isEmpty ? nil : try TemplateEngine.url(template: target.fallbackTemplate, query: text)
            let web = [primary, fallback].compactMap { $0 }.first { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
            opening = true
            notice = ""
            failedURL = nil
            failedWebURL = nil
            openingTask = Task { @MainActor in
                defer { opening = false }
                guard let openURL else { return }
                var accepted = await openURL(primary, compatibility)
                if !accepted, let fallback, !Task.isCancelled { accepted = await openURL(fallback, compatibility) }
                guard !Task.isCancelled else { return }
                if accepted { done?() }
                else {
                    failedURL = primary
                    failedWebURL = web
                    notice = "系统没有确认跳转。可在下方重试、转到主 App，或在这里搜索网页。"
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    func continueInApp() {
        guard !opening else { return }
        do {
            let handoff = try ShareHandoff(query: query, targetID: nil, run: false).url()
            opening = true
            openingTask = Task { @MainActor in
                defer { opening = false }
                let accepted = await openURL?(handoff, compatibility) ?? false
                guard !Task.isCancelled else { return }
                if accepted { done?() }
                else { error = "此系统或安装方式阻止了扩展跳转。可复制文字后打开 MyResearch；共享钥匙串可用时，下次扩展会直接显示同一份来源。" }
            }
        } catch { self.error = error.localizedDescription }
    }
    func browse(_ text: String, target: SearchTarget) {
        do {
            let primary = try TemplateEngine.url(template: target.template, query: text)
            if ["http", "https"].contains(primary.scheme?.lowercased() ?? "") { browser = BrowserDestination(url: primary) }
            else if !target.fallbackTemplate.isEmpty {
                browser = BrowserDestination(url: try TemplateEngine.url(template: target.fallbackTemplate, query: text))
            } else { error = "此来源没有网页兜底，请在主 App 中编辑。" }
        } catch { self.error = error.localizedDescription }
    }
}
