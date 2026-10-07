import SwiftUI
import UIKit

struct TranslationDestination: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var preferredTargetID: String?
}

private enum TranslationCardPhase: Equatable {
    case idle, loading, streaming, completed, failed
}

private struct TranslationCardState: Equatable {
    var phase: TranslationCardPhase = .idle
    var text = ""
    var error: String?
}

@MainActor
private final class TranslationResultsModel: ObservableObject {
    let text: String
    let sources: [SearchTarget]
    let preferredTargetID: String?

    @Published var sourceLanguage: String
    @Published var targetLanguage: String
    @Published var states: [String: TranslationCardState] = [:]

    private var tasks: [String: Task<Void, Never>] = [:]
    private var started = false

    init(destination: TranslationDestination, sources: [SearchTarget]) {
        text = destination.text
        preferredTargetID = destination.preferredTargetID
        self.sources = sources.filter { $0.kind == .translator && $0.enabled && $0.translator != nil }
        let route = TranslationLanguageRouter.route(destination.text)
        sourceLanguage = route.source
        targetLanguage = route.target
        states = Dictionary(uniqueKeysWithValues: self.sources.map { ($0.id, TranslationCardState()) })
    }

    func startAutomatic() {
        guard !started else { return }
        started = true
        let automatic = sources.filter {
            $0.id == preferredTargetID || ($0.translator?.autoRun ?? false)
        }
        if automatic.isEmpty, let first = sources.first {
            run(first)
        } else {
            automatic.forEach(run)
        }
    }

    func runAll() { sources.forEach(run) }

    func run(_ source: SearchTarget) {
        guard let configuration = source.translator else { return }
        tasks[source.id]?.cancel()
        states[source.id] = TranslationCardState(phase: .loading)

        let request = TranslationRequest(
            text: text,
            sourceLanguage: sourceLanguage == "auto" ? nil : sourceLanguage,
            targetLanguage: targetLanguage
        )

        tasks[source.id] = Task { [weak self] in
            guard let self else { return }
            do {
                var credential: String?
                if let id = configuration.credentialID {
                    credential = try SharedCredentialStore.value(for: id)
                    if credential == nil {
                        throw TranslationPresentationError.missingCredential(id)
                    }
                }
                let provider = try TranslationProviderFactory.make(
                    configuration: configuration,
                    credential: credential
                )
                var combined = ""
                for try await event in provider.translate(request) {
                    guard !Task.isCancelled else { return }
                    switch event {
                    case .delta(let value):
                        combined += value
                        states[source.id] = TranslationCardState(phase: .streaming, text: combined)
                    case .replacement(let value):
                        combined = value
                        states[source.id] = TranslationCardState(phase: .streaming, text: combined)
                    case .completed(let result):
                        combined = result.text
                        states[source.id] = TranslationCardState(phase: .completed, text: result.text)
                    }
                }
                if states[source.id]?.phase == .loading {
                    states[source.id] = TranslationCardState(
                        phase: .failed,
                        text: combined,
                        error: "翻译接口没有返回结果。"
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                states[source.id] = TranslationCardState(
                    phase: .failed,
                    text: states[source.id]?.text ?? "",
                    error: error.localizedDescription
                )
            }
        }
    }

    func swapLanguages() {
        if sourceLanguage == "auto" {
            let detected = TranslationLanguageRouter.detect(text)
            sourceLanguage = targetLanguage
            targetLanguage = detected ?? (sourceLanguage.lowercased().hasPrefix("zh") ? "en" : "zh")
        } else {
            let oldSource = sourceLanguage
            sourceLanguage = targetLanguage
            targetLanguage = oldSource
        }
        restartAutomatic()
    }

    func setSourceLanguage(_ value: String) {
        guard sourceLanguage != value else { return }
        sourceLanguage = value
        restartAutomatic()
    }

    func setTargetLanguage(_ value: String) {
        guard targetLanguage != value else { return }
        targetLanguage = value
        restartAutomatic()
    }

    func cancel() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func restartAutomatic() {
        cancel()
        states = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, TranslationCardState()) })
        started = false
        startAutomatic()
    }
}

private enum TranslationPresentationError: LocalizedError {
    case missingCredential(String)
    var errorDescription: String? {
        switch self {
        case .missingCredential(let id):
            return "缺少 API Key（Credential ID: \(id)）。请到「我的来源」编辑该翻译引擎。"
        }
    }
}

struct TranslationResultsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: TranslationResultsModel

    init(destination: TranslationDestination, sources: [SearchTarget]) {
        _model = StateObject(wrappedValue: TranslationResultsModel(destination: destination, sources: sources))
    }

    private let sourceLanguages = ["auto", "zh", "en", "ja", "ko", "fr", "de", "es"]
    private let targetLanguages = ["zh", "en", "ja", "ko", "fr", "de", "es"]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    languageBar
                    VStack(alignment: .leading, spacing: 8) {
                        Text("原文").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(model.text).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    }
                    .padding(14)
                    .background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 16))

                    if model.sources.isEmpty {
                        ContentUnavailableView(
                            "还没有翻译引擎",
                            systemImage: "character.book.closed",
                            description: Text("到「我的来源」添加 OpenAI-compatible 或通用 HTTP 翻译引擎。")
                        )
                        .padding(.top, 30)
                    } else {
                        ForEach(model.sources) { source in
                            card(source)
                        }
                    }
                }
                .padding(16)
            }
            .background(ResearchStyle.background)
            .navigationTitle("翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("全部翻译") { model.runAll() }.disabled(model.sources.isEmpty)
                }
            }
            .onAppear { model.startAutomatic() }
            .onDisappear { model.cancel() }
        }
    }

    private var languageBar: some View {
        HStack(spacing: 8) {
            languageMenu(
                code: model.sourceLanguage,
                values: sourceLanguages,
                select: model.setSourceLanguage
            )
            Spacer()
            Button { model.swapLanguages() } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.bordered)
            Spacer()
            languageMenu(
                code: model.targetLanguage,
                values: targetLanguages,
                select: model.setTargetLanguage
            )
        }
        .padding(.horizontal, 4)
    }

    private func languageMenu(code: String, values: [String], select: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(values, id: \.self) { value in
                Button {
                    select(value)
                } label: {
                    if value == code {
                        Label(TranslationLanguageRouter.displayName(value), systemImage: "checkmark")
                    } else {
                        Text(TranslationLanguageRouter.displayName(value))
                    }
                }
            }
        } label: {
            Text(TranslationLanguageRouter.displayName(code))
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 74, minHeight: 40)
        }
        .buttonStyle(.bordered)
    }

    private func card(_ source: SearchTarget) -> some View {
        let state = model.states[source.id] ?? TranslationCardState()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TargetIcon(target: source, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name).font(.body.weight(.semibold))
                    Text(source.translator?.engine.title ?? "翻译")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if state.phase == .loading || state.phase == .streaming {
                    ProgressView().controlSize(.small)
                }
            }

            if !state.text.isEmpty {
                Text(state.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else if state.phase == .idle {
                Text("未请求").foregroundStyle(.tertiary)
            } else if state.phase == .loading {
                Text("正在连接…").foregroundStyle(.secondary)
            }

            if let error = state.error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }

            HStack {
                Button(state.phase == .idle ? "翻译" : "重试") { model.run(source) }
                    .buttonStyle(.bordered)
                Spacer()
                if !state.text.isEmpty {
                    Button {
                        UIPasteboard.general.string = state.text
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}
