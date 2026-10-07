import SwiftUI

struct TranslationLaunchRequest: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var preferredTargetID: String
    var recordHistory: Bool
}

struct TranslationLauncherView: View {
    let request: TranslationLaunchRequest
    let provider: SearchTarget
    let settings: AppSettings
    let onCancel: () -> Void
    let onConfirm: (_ sourceLanguage: String, _ targetLanguage: String) -> Void

    @State private var sourceLanguage: String
    @State private var targetLanguage: String
    private let detectedLanguage: String?

    init(
        request: TranslationLaunchRequest,
        provider: SearchTarget,
        settings: AppSettings,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (_ sourceLanguage: String, _ targetLanguage: String) -> Void
    ) {
        self.request = request
        self.provider = provider
        self.settings = settings
        self.onCancel = onCancel
        self.onConfirm = onConfirm

        let detected = TranslationLanguageRouter.detect(request.text)
        detectedLanguage = detected
        let route = TranslationLanguageRouter.route(
            request.text,
            preferredTarget: settings.translationPreferredTargetLanguage,
            lastSource: settings.lastTranslationSourceLanguage,
            lastTarget: settings.lastTranslationTargetLanguage
        )
        _sourceLanguage = State(initialValue: route.source)
        _targetLanguage = State(initialValue: route.target)
    }

    private var recommendationSource: String {
        if sourceLanguage == "auto" {
            return detectedLanguage ?? "auto"
        }
        return sourceLanguage
    }

    private var recommendations: [TranslationPairOption] {
        TranslationLanguageRouter.suggestedPairs(
            for: request.text,
            selectedSource: sourceLanguage,
            preferredTarget: settings.translationPreferredTargetLanguage,
            lastSource: settings.lastTranslationSourceLanguage,
            lastTarget: settings.lastTranslationTargetLanguage
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    providerHeader
                    sourcePreview
                    pairCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(ResearchStyle.background)
            .navigationTitle("翻译设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onConfirm(sourceLanguage, targetLanguage)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("\(TranslationLanguageRouter.displayName(sourceLanguage)) → \(TranslationLanguageRouter.displayName(targetLanguage)) · 翻译")
                            .lineLimit(1)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(ResearchStyle.accent, in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("translation-launch-confirm")
                .disabled(targetLanguage == sourceLanguage)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var providerHeader: some View {
        HStack(spacing: 12) {
            TargetIcon(target: provider, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name)
                    .font(.headline)
                Text(provider.translator?.engine.title ?? "翻译")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let detectedLanguage {
                HStack(spacing: 5) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                    Text("识别为 \(TranslationLanguageRouter.displayName(detectedLanguage))")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(ResearchStyle.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(ResearchStyle.accent.opacity(0.10), in: Capsule())
            }
        }
        .padding(14)
        .background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var sourcePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("待翻译", systemImage: "text.quote")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(request.text)
                .font(.body)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var pairCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("语对")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if detectedLanguage != nil {
                    Text("按识别语言推荐")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                languageMenu(
                    title: "源语言",
                    value: sourceLanguage,
                    values: TranslationLanguageRouter.sourceLanguages
                ) { value in
                    sourceLanguage = value
                    normalizeTarget()
                }

                Button {
                    swapLanguages()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ResearchStyle.accent)
                        .frame(width: 42, height: 42)
                        .background(ResearchStyle.accent.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("交换语言")

                languageMenu(
                    title: "目标语言",
                    value: targetLanguage,
                    values: TranslationLanguageRouter.targetLanguages
                ) { value in
                    targetLanguage = value
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(ResearchStyle.accent)
                    Text("\(TranslationLanguageRouter.displayName(recommendationSource)) 常用方向")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if settings.lastTranslationSourceLanguage == recommendationSource,
                       let last = settings.lastTranslationTargetLanguage {
                        Text("上次 → \(TranslationLanguageRouter.shortName(last))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(recommendations) { pair in
                        let effectiveSource = sourceLanguage == "auto" ? recommendationSource : sourceLanguage
                        let selected = effectiveSource == pair.source && targetLanguage == pair.target
                        Button {
                            sourceLanguage = pair.source
                            targetLanguage = pair.target
                        } label: {
                            Text(pair.compactTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selected ? ResearchStyle.accent : .primary)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(
                                    selected ? ResearchStyle.accent.opacity(0.11) : ResearchStyle.elevated,
                                    in: RoundedRectangle(cornerRadius: 11)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 11)
                                        .strokeBorder(selected ? ResearchStyle.accent.opacity(0.42) : Color.clear, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("translation-pair-\(pair.source)-\(pair.target)")
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func languageMenu(
        title: String,
        value: String,
        values: [String],
        select: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(values, id: \.self) { code in
                Button {
                    select(code)
                } label: {
                    if code == value {
                        Label(TranslationLanguageRouter.displayName(code), systemImage: "checkmark")
                    } else {
                        Text(TranslationLanguageRouter.displayName(code))
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                HStack(spacing: 5) {
                    Text(TranslationLanguageRouter.displayName(value))
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

    private func normalizeTarget() {
        let effectiveSource = sourceLanguage == "auto" ? detectedLanguage ?? "auto" : sourceLanguage
        if targetLanguage == effectiveSource {
            targetLanguage = TranslationLanguageRouter.defaultTarget(for: effectiveSource)
        }
    }

    private func swapLanguages() {
        let effectiveSource = sourceLanguage == "auto" ? detectedLanguage ?? "auto" : sourceLanguage
        let previousTarget = targetLanguage
        if previousTarget == "auto" { return }
        sourceLanguage = previousTarget
        if effectiveSource == "auto" || effectiveSource == previousTarget {
            targetLanguage = TranslationLanguageRouter.defaultTarget(for: previousTarget)
        } else {
            targetLanguage = effectiveSource
        }
    }
}
