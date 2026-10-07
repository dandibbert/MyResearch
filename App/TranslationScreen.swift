import SwiftUI
import UIKit

struct TranslationDestination: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var preferredTargetID: String?
}

private enum TranslationCardPhase: Equatable {
    case idle, loading, streaming, completed, failed

    var title: String {
        switch self {
        case .idle: return "待运行"
        case .loading: return "连接中"
        case .streaming: return "生成中"
        case .completed: return "完成"
        case .failed: return "失败"
        }
    }

    var symbol: String {
        switch self {
        case .idle: return "circle"
        case .loading: return "arrow.triangle.2.circlepath"
        case .streaming: return "ellipsis"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        }
    }
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
            targetLanguage = detected ?? (targetLanguage.lowercased().hasPrefix("zh") ? "en" : "zh")
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
            return "缺少 API Key（\(id)）。到「我的来源」编辑这个翻译引擎即可补上。"
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
                LazyVStack(spacing: 14) {
                    directionCard
                    sourceCard

                    if model.sources.isEmpty {
                        emptyState
                    } else {
                        ForEach(model.sources) { source in
                            resultCard(source)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(ResearchStyle.background)
            .navigationTitle("翻译")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !model.sources.isEmpty {
                        Button {
                            model.runAll()
                        } label: {
                            Label("全部", systemImage: "play.fill")
                        }
                    }
                }
            }
            .onAppear { model.startAutomatic() }
            .onDisappear { model.cancel() }
        }
    }

    private var directionCard: some View {
        HStack(spacing: 10) {
            languagePill(
                title: "源语言",
                code: model.sourceLanguage,
                values: sourceLanguages,
                select: model.setSourceLanguage
            )

            Button { model.swapLanguages() } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(ResearchStyle.accent)
                    .frame(width: 42, height: 42)
                    .background(ResearchStyle.accent.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("对调语言")

            languagePill(
                title: "目标语言",
                code: model.targetLanguage,
                values: targetLanguages,
                select: model.setTargetLanguage
            )
        }
        .padding(12)
        .background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private func languagePill(
        title: String,
        code: String,
        values: [String],
        select: @escaping (String) -> Void
    ) -> some View {
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
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                HStack(spacing: 5) {
                    Text(TranslationLanguageRouter.displayName(code))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(ResearchStyle.elevated, in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("原文", systemImage: "text.quote")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = model.text
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("复制原文")
            }

            Text(model.text)
                .font(.body)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(15)
        .background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            IconGlyph(storedValue: "ph:translate", tintHex: "5265DE", size: 34)
                .frame(width: 58, height: 58)
                .background(ResearchStyle.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
            Text("还没有翻译引擎")
                .font(.headline)
            Text("到「我的来源」→「+」→「从预设添加」，可以直接加 Google、DeepLX、DeepL、Microsoft 等翻译来源。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
        .background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private func resultCard(_ source: SearchTarget) -> some View {
        let state = model.states[source.id] ?? TranslationCardState()
        let tint = Color(hex: source.tintHex)

        return VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                TargetIcon(target: source, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(source.name)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)

                        if source.translator?.autoRun == true {
                            Text("AUTO")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(tint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(tint.opacity(0.10), in: Capsule())
                        }
                    }

                    Text(providerSubtitle(source))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                HStack(spacing: 5) {
                    if state.phase == .loading || state.phase == .streaming {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: state.phase.symbol)
                            .font(.caption)
                    }
                    Text(state.phase.title)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(statusColor(state.phase, tint: tint))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(statusColor(state.phase, tint: tint).opacity(0.08), in: Capsule())
            }

            Group {
                if !state.text.isEmpty {
                    Text(state.text)
                        .font(.body)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
                        .textSelection(.enabled)
                } else if state.phase == .loading {
                    Text("正在连接翻译服务…")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
                } else if state.phase == .failed {
                    Text("这次没有拿到译文。")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
                } else {
                    Text("这个引擎没有自动运行。点下方「翻译」即可单独请求。")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
                }
            }
            .padding(12)
            .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))

            if let error = state.error {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Button {
                    model.run(source)
                } label: {
                    Label(state.phase == .idle ? "翻译" : "重试", systemImage: state.phase == .idle ? "play.fill" : "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if !state.text.isEmpty {
                    Button {
                        UIPasteboard.general.string = state.text
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()
            }
        }
        .padding(15)
        .background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(tint.opacity(0.12), lineWidth: 1)
        }
    }

    private func providerSubtitle(_ source: SearchTarget) -> String {
        guard let translator = source.translator else { return "翻译" }
        switch source.id {
        case "translate-google-gtx": return "Google · 免 Key"
        case "translate-deeplx": return "DeepLX · 自建实例"
        case "translate-deepl-api": return "DeepL API"
        case "translate-microsoft": return "Microsoft Translator"
        default:
            switch translator.engine {
            case .openAIChat: return translator.openAI?.model.isEmpty == false ? (translator.openAI?.model ?? "OpenAI-compatible") : "OpenAI-compatible"
            case .http:
                if let raw = translator.http?.url, let host = URL(string: raw)?.host { return host }
                return "通用 HTTP"
            }
        }
    }

    private func statusColor(_ phase: TranslationCardPhase, tint: Color) -> Color {
        switch phase {
        case .completed: return .green
        case .failed: return .red
        case .loading, .streaming: return tint
        case .idle: return .secondary
        }
    }
}
