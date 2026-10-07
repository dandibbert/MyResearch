import SwiftUI

struct IconCatalogEntry: Identifiable, Hashable {
    let rawValue: String
    let title: String
    let keywords: [String]
    let category: String
    var id: String { rawValue }
    var storedValue: String { "ph:" + rawValue }
}

enum IconCatalog {
    static let categories = ["搜索与网页", "翻译与 AI", "内容与资料", "开发与工具", "媒体与服务", "其他"]

    static let featured: [IconCatalogEntry] = [
        .init(rawValue: "magnifying-glass", title: "搜索", keywords: ["search", "find", "查找"], category: "搜索与网页"),
        .init(rawValue: "binoculars", title: "探索", keywords: ["discover", "探索"], category: "搜索与网页"),
        .init(rawValue: "compass", title: "指南针", keywords: ["navigate", "导航"], category: "搜索与网页"),
        .init(rawValue: "globe", title: "网页", keywords: ["web", "global", "网络"], category: "搜索与网页"),
        .init(rawValue: "browser", title: "浏览器", keywords: ["browser", "网页"], category: "搜索与网页"),
        .init(rawValue: "link", title: "链接", keywords: ["url", "link"], category: "搜索与网页"),
        .init(rawValue: "target", title: "目标", keywords: ["target", "定位"], category: "搜索与网页"),
        .init(rawValue: "crosshair", title: "定位", keywords: ["focus", "定位"], category: "搜索与网页"),
        .init(rawValue: "map-trifold", title: "地图", keywords: ["map", "地图"], category: "搜索与网页"),
        .init(rawValue: "map-pin", title: "地点", keywords: ["location", "地点"], category: "搜索与网页"),

        .init(rawValue: "translate", title: "翻译", keywords: ["translate", "语言", "翻译"], category: "翻译与 AI"),
        .init(rawValue: "text-aa", title: "文字", keywords: ["text", "文字"], category: "翻译与 AI"),
        .init(rawValue: "chat-circle-text", title: "问答", keywords: ["chat", "qa", "问答"], category: "翻译与 AI"),
        .init(rawValue: "chats-circle", title: "对话", keywords: ["chat", "对话"], category: "翻译与 AI"),
        .init(rawValue: "robot", title: "AI", keywords: ["ai", "robot", "模型"], category: "翻译与 AI"),
        .init(rawValue: "brain", title: "思考", keywords: ["brain", "think", "思考"], category: "翻译与 AI"),
        .init(rawValue: "sparkle", title: "智能", keywords: ["sparkle", "magic", "AI"], category: "翻译与 AI"),
        .init(rawValue: "magic-wand", title: "魔法棒", keywords: ["magic", "生成"], category: "翻译与 AI"),
        .init(rawValue: "book-open-text", title: "词典", keywords: ["dictionary", "词典"], category: "翻译与 AI"),
        .init(rawValue: "books", title: "资料库", keywords: ["books", "knowledge", "知识"], category: "翻译与 AI"),

        .init(rawValue: "article", title: "文章", keywords: ["article", "文章"], category: "内容与资料"),
        .init(rawValue: "newspaper", title: "新闻", keywords: ["news", "新闻"], category: "内容与资料"),
        .init(rawValue: "file-text", title: "文档", keywords: ["document", "文档"], category: "内容与资料"),
        .init(rawValue: "folder-open", title: "文件夹", keywords: ["folder", "文件夹"], category: "内容与资料"),
        .init(rawValue: "bookmark", title: "收藏", keywords: ["bookmark", "收藏"], category: "内容与资料"),
        .init(rawValue: "tag", title: "标签", keywords: ["tag", "标签"], category: "内容与资料"),
        .init(rawValue: "image", title: "图片", keywords: ["image", "图片"], category: "内容与资料"),
        .init(rawValue: "camera", title: "相机", keywords: ["camera", "相机"], category: "内容与资料"),
        .init(rawValue: "music-notes", title: "音乐", keywords: ["music", "音乐"], category: "内容与资料"),
        .init(rawValue: "play-circle", title: "视频", keywords: ["video", "play", "视频"], category: "内容与资料"),

        .init(rawValue: "code", title: "代码", keywords: ["code", "开发"], category: "开发与工具"),
        .init(rawValue: "terminal-window", title: "终端", keywords: ["terminal", "命令行"], category: "开发与工具"),
        .init(rawValue: "database", title: "数据库", keywords: ["database", "数据"], category: "开发与工具"),
        .init(rawValue: "flask", title: "实验", keywords: ["lab", "实验"], category: "开发与工具"),
        .init(rawValue: "calculator", title: "计算", keywords: ["calculator", "计算"], category: "开发与工具"),
        .init(rawValue: "package", title: "包", keywords: ["package", "包"], category: "开发与工具"),
        .init(rawValue: "tree-structure", title: "结构", keywords: ["tree", "structure", "结构"], category: "开发与工具"),
        .init(rawValue: "squares-four", title: "应用", keywords: ["apps", "grid", "应用"], category: "开发与工具"),

        .init(rawValue: "google-logo", title: "Google", keywords: ["google"], category: "媒体与服务"),
        .init(rawValue: "github-logo", title: "GitHub", keywords: ["github"], category: "媒体与服务"),
        .init(rawValue: "youtube-logo", title: "YouTube", keywords: ["youtube", "视频"], category: "媒体与服务"),
        .init(rawValue: "reddit-logo", title: "Reddit", keywords: ["reddit"], category: "媒体与服务"),
        .init(rawValue: "apple-logo", title: "Apple", keywords: ["apple"], category: "媒体与服务"),
        .init(rawValue: "windows-logo", title: "Microsoft", keywords: ["microsoft", "windows"], category: "媒体与服务"),
        .init(rawValue: "rss", title: "RSS", keywords: ["rss", "订阅"], category: "媒体与服务"),
        .init(rawValue: "paper-plane-tilt", title: "发送", keywords: ["send", "发送"], category: "媒体与服务"),

        .init(rawValue: "lightning", title: "闪电", keywords: ["fast", "快捷"], category: "其他"),
        .init(rawValue: "star", title: "星标", keywords: ["star", "收藏"], category: "其他"),
        .init(rawValue: "heart", title: "喜欢", keywords: ["heart", "喜欢"], category: "其他"),
        .init(rawValue: "clock", title: "时间", keywords: ["clock", "时间"], category: "其他"),
        .init(rawValue: "rocket-launch", title: "启动", keywords: ["rocket", "启动"], category: "其他"),
        .init(rawValue: "atom", title: "原子", keywords: ["atom", "科学"], category: "其他"),
        .init(rawValue: "cloud", title: "云", keywords: ["cloud", "云"], category: "其他"),
        .init(rawValue: "cube", title: "模块", keywords: ["cube", "模块"], category: "其他")
    ]

    static let systemSymbols: [(name: String, title: String)] = [
        ("magnifyingglass", "搜索"), ("globe", "网页"), ("link", "链接"), ("bolt.fill", "闪电"),
        ("character.book.closed.fill", "翻译"), ("text.bubble.fill", "对话"), ("book.closed.fill", "书籍"),
        ("play.rectangle.fill", "视频"), ("bag.fill", "购物"), ("map.fill", "地图"),
        ("terminal.fill", "终端"), ("star.fill", "星标"), ("heart.fill", "喜欢"),
        ("doc.text.fill", "文档"), ("photo.fill", "图片"), ("camera.fill", "相机"),
        ("music.note", "音乐"), ("folder.fill", "文件夹"), ("bookmark.fill", "收藏"),
        ("paperplane.fill", "发送"), ("sparkles", "智能"), ("brain.head.profile", "思考"),
        ("questionmark.circle.fill", "问答"), ("network", "网络")
    ]

    private static let featuredByRaw = Dictionary(uniqueKeysWithValues: featured.map { ($0.rawValue, $0) })

    static func displayName(for storedValue: String) -> String {
        if storedValue.hasPrefix("ph:") {
            let raw = String(storedValue.dropFirst(3))
            if let featured = featuredByRaw[raw] { return featured.title }
            return raw.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
        }
        return systemSymbols.first(where: { $0.name == storedValue })?.title ?? storedValue
    }

    static func searchPhosphor(_ query: String) -> [IconCatalogEntry] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return [] }
        return featured.filter { item in
            ([item.title, item.rawValue] + item.keywords)
                .joined(separator: " ")
                .lowercased()
                .contains(term)
        }
    }
}

struct IconPickerSheet: View {
    @Binding var selection: String
    var tintHex: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var library = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("图标库", selection: $library) {
                        Text("Phosphor").tag(0)
                        Text("系统").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if library == 0 {
                        phosphorContent
                    } else {
                        systemContent
                    }
                }
                .padding(.vertical, 8)
            }
            .background(ResearchStyle.background)
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: library == 0 ? "搜索 Phosphor 图标" : "搜索系统图标")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
    }

    @ViewBuilder
    private var phosphorContent: some View {
        let results = IconCatalog.searchPhosphor(search)
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            iconGrid(results)
                .padding(.horizontal, 14)
        } else {
            ForEach(IconCatalog.categories, id: \.self) { category in
                let values = IconCatalog.featured.filter { $0.category == category }
                VStack(alignment: .leading, spacing: 10) {
                    Text(category).font(.headline).padding(.horizontal, 18)
                    iconGrid(values).padding(.horizontal, 14)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("更多图标").font(.headline)
                Text("内置 \(IconCatalog.featured.count) 个适合搜索、翻译、AI、内容和工具的 Phosphor 图标；也保留一组系统图标兼容旧配置。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
        }
    }

    private var systemContent: some View {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let values = IconCatalog.systemSymbols.filter {
            term.isEmpty || $0.name.lowercased().contains(term) || $0.title.lowercased().contains(term)
        }
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(values, id: \.name) { item in
                iconButton(storedValue: item.name, title: item.title)
            }
        }
        .padding(.horizontal, 14)
    }

    private func iconGrid(_ entries: [IconCatalogEntry]) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(entries) { item in
                iconButton(storedValue: item.storedValue, title: item.title)
            }
        }
    }

    private func iconButton(storedValue: String, title: String) -> some View {
        let selected = selection == storedValue
        return Button {
            selection = storedValue
        } label: {
            VStack(spacing: 7) {
                IconGlyph(storedValue: storedValue, tintHex: tintHex, size: 27)
                    .frame(width: 34, height: 34)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .padding(.horizontal, 4)
            .background(selected ? Color(hex: tintHex).opacity(0.14) : ResearchStyle.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? Color(hex: tintHex).opacity(0.55) : Color.primary.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
