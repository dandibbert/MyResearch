import SwiftUI

struct SearchScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var suggestions = SuggestionsModel()
    @State private var focused = false
    private var intent: SearchIntent { SearchRouter.intent(for: store.query, configuration: store.configuration) }
    private var currentTarget: SearchTarget? {
        store.configuration.enabledTargets.first { $0.id == intent.targetID } ?? store.configuration.defaultTarget
    }
    private var visibleSourceRows: Int { verticalSizeClass == .compact ? 1 : 2 }
    private var sourceViewportHeight: CGFloat {
        CGFloat(visibleSourceRows * 48 + max(0, visibleSourceRows - 1))
    }
    private var sourceSectionHeight: CGFloat { 20 + 5 + sourceViewportHeight + 12 }

    var body: some View {
        VStack(spacing: 0) {
            if verticalSizeClass != .compact {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(ResearchStyle.accent)
                    Text("MyResearch").font(.system(.title3, design: .rounded, weight: .bold))
                }
                Spacer()
                Button { focused.toggle() } label: {
                    Image(systemName: focused ? "keyboard.chevron.compact.down" : "keyboard")
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel(focused ? "收起键盘" : "打开键盘").accessibilityIdentifier("toggle-keyboard")
            }.padding(.horizontal, 20).frame(height: 48)
            }
            if !store.configuration.settings.thumbLayout { composer }
            GeometryReader { _ in
                VStack(spacing: 8) {
                    // Keep the source card on complete 48-point rows so its lower edge
                    // never looks like a clipped extra item.
                    sourceSection.frame(height: sourceSectionHeight)
                    candidateSection.frame(maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 16).padding(.top, 4).clipped()
            if !intent.query.isEmpty {
                CandidateRow(query: intent.query, targets: store.configuration.quickTargets, original: true,
                             search: { source in store.search(intent.query, target: source ?? currentTarget) }, fill: nil)
                    .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 2)
            }
            if store.configuration.settings.thumbLayout { composer }
        }
        .onAppear { focusSoon(); refresh() }
        .onDisappear { suggestions.cancel() }
        .onChange(of: store.query) { refresh() }
        .onChange(of: store.configuration) { refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { focusSoon() } }
    }

    private var composer: some View {
        HStack(spacing: 4) {
            Image(systemName: intent.targetID == nil ? "magnifyingglass" : "bolt.fill")
                .foregroundStyle(ResearchStyle.accent).padding(.leading, 13)
            SearchField(text: $store.query, focused: $focused) { submit() }
                .frame(height: 48)
            if verticalSizeClass == .compact {
                Button { focused = false } label: { Image(systemName: "keyboard.chevron.compact.down").frame(width: 44, height: 44) }.accessibilityLabel("收起键盘").accessibilityIdentifier("toggle-keyboard")
            }
            if !store.query.isEmpty {
                Button { store.query = ""; focused = true } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary).frame(width: 44, height: 44)
                }.accessibilityLabel("清空输入").accessibilityIdentifier("clear-query")
            } else {
                PasteButton(payloadType: String.self) { values in
                    if let first = values.first { store.query = String(first.prefix(4096)); focused = true }
                }.labelStyle(.iconOnly).buttonBorderShape(.roundedRectangle).scaleEffect(0.85)
                    .accessibilityLabel("粘贴文字")
            }
            Button { submit() } label: {
                Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(ResearchStyle.accent, in: RoundedRectangle(cornerRadius: 13))
            }.padding(.trailing, 5).accessibilityLabel("搜索").accessibilityIdentifier("submit-search")
        }
        .background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(ResearchStyle.accent.opacity(focused ? 0.35 : 0.12), lineWidth: 1) }
        .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 8)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(intent.targetID == nil ? "搜索到" : "闪电 · \(currentTarget?.name ?? "")")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("\(store.configuration.enabledTargets.count) 个来源").font(.caption2).foregroundStyle(.tertiary)
            }.frame(height: 20).padding(.horizontal, 4)
            if store.configuration.enabledTargets.isEmpty {
                Button("添加搜索来源") { focused = false; store.selectedTab = 1 }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.configuration.enabledTargets) { target in
                            Button { store.search(intent.query, target: target) } label: { SourceRow(target: target) }
                                .buttonStyle(.plain).disabled(intent.query.isEmpty && !target.isAction)
                                .accessibilityIdentifier("source-\(target.id)")
                            if target.id != store.configuration.enabledTargets.last?.id { Divider().padding(.leading, 46) }
                        }
                    }.padding(.horizontal, 12)
                }
                    .frame(height: sourceViewportHeight)
                    .scrollDismissesKeyboard(.never)
                    .padding(.vertical, 6)
                    .background(ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(intent.query.isEmpty ? "最近搜索" : "联想 · \(suggestions.status)")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
                if suggestions.loading { ProgressView().controlSize(.mini) }
            }.frame(height: 22).padding(.horizontal, 4)
            if intent.query.isEmpty {
                if store.history.isEmpty || !store.configuration.settings.historyEnabled {
                    emptyState("输入一次，搜到任何地方", detail: "打开即输入 · 一次点击跳转")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(store.history.prefix(12)) { item in
                                Button { store.query = item.query; focused = true } label: {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                                        Text(item.query).lineLimit(1).foregroundStyle(.primary)
                                        Spacer(); Image(systemName: "arrow.up.left").foregroundStyle(.tertiary)
                                    }.font(.subheadline).padding(.horizontal, 10).frame(minHeight: 44).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }
                    }.scrollDismissesKeyboard(.never)
                }
            } else if suggestions.values.isEmpty {
                emptyState(suggestions.loading ? "正在获取联想…" : "直接搜索下方原词", detail: "原词固定在手边，不随候选移动")
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(suggestions.values, id: \.self) { word in
                            CandidateRow(query: word, targets: store.configuration.quickTargets, original: false,
                                         search: { source in store.search(word, target: source ?? currentTarget) },
                                         fill: { store.query = word; focused = true })
                        }
                    }
                }.scrollDismissesKeyboard(.never)
            }
        }
    }
    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(spacing: 7) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(detail).font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 8)
    }
    private func submit() { store.search(intent.query, target: currentTarget) }
    private func refresh() {
        suggestions.refresh(query: intent.query, settings: store.configuration.settings, history: store.history, testMode: store.testMode)
    }
    private func focusSoon() {
        guard store.configuration.settings.autoFocus else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { focused = true }
    }
}

struct CandidateRow: View {
    var query: String
    var targets: [SearchTarget]
    var original: Bool
    var search: (SearchTarget?) -> Void
    var fill: (() -> Void)?
    var body: some View {
        HStack(spacing: 0) {
            Button { search(nil) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    if original { Text("原词").font(.system(size: 10, weight: .semibold)).foregroundStyle(ResearchStyle.accent) }
                    Text(query).font(original ? .subheadline.weight(.semibold) : .subheadline).lineLimit(1).foregroundStyle(.primary)
                }.frame(maxWidth: .infinity, minHeight: original ? 58 : 48, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("搜索\(query)")
                .accessibilityIdentifier(original ? "original-query" : "candidate-\(query)")
            if let fill {
                Button(action: fill) { Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(.tertiary).frame(width: 44, height: 44) }
                    .accessibilityLabel("将\(query)填入搜索框")
            }
            if !targets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(targets) { target in
                            Button { search(target) } label: {
                                TargetIcon(target: target, size: 29)
                                    .frame(width: 44, height: 44).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).accessibilityLabel("用\(target.name)搜索\(query)")
                            .accessibilityIdentifier(original ? "original-\(target.id)" : "candidate-\(target.id)-\(query)")
                        }
                    }
                }
                .frame(width: min(CGFloat(targets.count) * 44, 132), height: 44)
            }
        }
        .padding(.leading, 12).padding(.trailing, 4)
        .background(original ? ResearchStyle.accent.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
    }
}
