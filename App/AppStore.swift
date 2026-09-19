import SwiftUI
import UIKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var configuration = Configuration.initial
    @Published private(set) var history: [HistoryItem] = []
    @Published var query = ""
    @Published var selectedTab = 0
    @Published var errorMessage: String?
    @Published var lastOpenedURL = ""
    @Published private(set) var isOpening = false
    @Published private(set) var sharingStatus = "尚未写入共享配置"
    let testMode = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    private var storageBlocked = false
    private let fileURL: URL
    private struct SavedState: Codable { var configuration: Configuration; var history: [HistoryItem] }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        fileURL = base.appendingPathComponent("MyResearch", isDirectory: true).appendingPathComponent("library.json")
        defer { if !storageBlocked { publishSharing(configuration) } }
        if testMode {
            if ProcessInfo.processInfo.arguments.contains("--share-fixture") {
                configuration.targets.insert(SearchTarget(id: "share-probe", name: "测试目标 App", symbol: "arrow.up.forward.app", template: "myresearch-probe://search?q={query}", aliases: ["probe"], quickAccess: true), at: 0)
                configuration.targets.insert(SearchTarget(id: "share-missing", name: "未安装的目标", template: "myresearch-missing-app://search?q={query}"), at: 1)
                configuration.settings.defaultTargetID = "google"
                configuration.settings.provider = .off
            }
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--query=") }) {
                query = String(argument.dropFirst(8))
            }
            return
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: fileURL))
            try ConfigurationCodec.validate(state.configuration)
            configuration = state.configuration
            history = Array(state.history.prefix(100))
        } catch {
            storageBlocked = true
            errorMessage = "本地配置读取失败。原文件已保留，不会覆盖；请通过设置导入有效配置以恢复。"
        }
    }

    private func persist(_ config: Configuration, _ records: [HistoryItem], recovering: Bool = false) throws {
        try ConfigurationCodec.validate(config)
        guard !testMode else { publishSharing(config); return }
        if storageBlocked && !recovering { throw ResearchError("原配置无法读取。请先在设置中导入有效配置；原文件会被备份。") }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if recovering && FileManager.default.fileExists(atPath: fileURL.path) {
            let backup = directory.appendingPathComponent("library-before-import-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: fileURL, to: backup)
        }
        let data = try JSONEncoder().encode(SavedState(configuration: config, history: records))
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        publishSharing(config)
    }
    func replaceConfiguration(_ newValue: Configuration) throws {
        try persist(newValue, history, recovering: true)
        storageBlocked = false
        configuration = newValue
    }
    func updateSettings(_ edit: (inout AppSettings) -> Void) {
        var next = configuration
        edit(&next.settings)
        commit(next)
    }
    func upsert(_ target: SearchTarget) throws {
        var next = configuration
        if let index = next.targets.firstIndex(where: { $0.id == target.id }) { next.targets[index] = target }
        else { next.targets.append(target) }
        try persist(next, history)
        configuration = next
    }
    func delete(at offsets: IndexSet) {
        var next = configuration
        next.targets.remove(atOffsets: offsets)
        commit(next)
    }
    func move(from offsets: IndexSet, to destination: Int) {
        var next = configuration
        next.targets.move(fromOffsets: offsets, toOffset: destination)
        commit(next)
    }
    func setEnabled(_ enabled: Bool, id: String) {
        var next = configuration
        guard let index = next.targets.firstIndex(where: { $0.id == id }) else { return }
        next.targets[index].enabled = enabled
        commit(next)
    }
    private func commit(_ next: Configuration) {
        do { try persist(next, history); configuration = next }
        catch { errorMessage = error.localizedDescription }
    }
    func clearHistory() {
        do { try persist(configuration, []); history = [] }
        catch { errorMessage = error.localizedDescription }
    }
    private func record(query: String, target: SearchTarget) {
        guard configuration.settings.historyEnabled, !target.isAction else { return }
        let next = SuggestionLogic.recording(history, query: query, targetID: target.id)
        do { try persist(configuration, next); history = next }
        catch { errorMessage = error.localizedDescription }
    }
    func search(_ text: String, target: SearchTarget?, recordHistory: Bool = true) {
        guard !isOpening else { return }
        guard let target else { errorMessage = "没有启用的搜索来源。请到「我的链接」添加或启用一个。"; return }
        let url: URL
        do { url = try TemplateEngine.url(template: target.template, query: text) }
        catch { errorMessage = error.localizedDescription; return }
        isOpening = true
        Task { @MainActor in
            defer { isOpening = false }
            if testMode { lastOpenedURL = url.absoluteString; return }
            var opened = await UIApplication.shared.open(url, options: [:])
            if !opened, !target.fallbackTemplate.isEmpty {
                do {
                    let fallback = try TemplateEngine.url(template: target.fallbackTemplate, query: text)
                    opened = await UIApplication.shared.open(fallback, options: [:])
                } catch { errorMessage = error.localizedDescription; return }
            }
            if opened {
                if recordHistory { record(query: text, target: target) }
            } else {
                errorMessage = "无法打开「\(target.name)」。目标 App 可能未安装，或不支持此链接。可编辑链接并配置 HTTPS 兜底。\n\n\(url.absoluteString)"
            }
        }
    }
    private func publishSharing(_ config: Configuration) {
        do {
            try SharedConfiguration.publish(config)
            sharingStatus = "已写入共享钥匙串；扩展可用性以扩展内状态为准"
        } catch { sharingStatus = error.localizedDescription }
    }
    func refreshSharing() { if !storageBlocked { publishSharing(configuration) } }
    func receive(_ url: URL) {
        guard let handoff = ShareHandoff.parse(url) else { return }
        query = handoff.query
        selectedTab = 0
        guard handoff.run else { return }
        let intent = SearchRouter.intent(for: query, configuration: configuration)
        if let id = handoff.targetID {
            guard let target = configuration.enabledTargets.first(where: { $0.id == id }) else {
                errorMessage = "分享指定的来源已删除或停用，请重新选择。"
                return
            }
            search(intent.query, target: target)
        } else {
            search(intent.query, target: configuration.enabledTargets.first { $0.id == intent.targetID } ?? configuration.defaultTarget)
        }
    }
}
