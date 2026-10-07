import Foundation
#if SWIFT_PACKAGE
import TranslationCore
#endif

enum Presets {
    static let search: [SearchTarget] = [
        item("google", "Google", "ph:google-logo", "4285F4", "https://www.google.com/search?q={query}", ["g", "google"], true),
        item("bilibili", "哔哩哔哩", "ph:play-circle", "E777A0", "https://search.bilibili.com/all?keyword={query}", ["b", "bili"], true),
        item("xiaohongshu", "小红书", "ph:book-open-text", "EB4B65", "https://www.xiaohongshu.com/search_result?keyword={query}", ["xhs"], true),
        item("bing", "Bing", "ph:magnifying-glass", "148C95", "https://www.bing.com/search?q={query}", ["bing"]),
        item("baidu", "百度", "ph:magnifying-glass", "405CE1", "https://www.baidu.com/s?wd={query}", ["bd"]),
        item("youtube", "YouTube", "ph:youtube-logo", "E84848", "https://www.youtube.com/results?search_query={query}", ["yt"]),
        item("taobao", "淘宝", "ph:shopping-bag", "EB7D32", "https://s.taobao.com/search?q={query}", ["tb"]),
        item("jd", "京东", "ph:package", "DA4B51", "https://search.jd.com/Search?keyword={query}", ["jd"]),
        item("zhihu", "知乎", "ph:chat-circle-text", "387CD4", "https://www.zhihu.com/search?type=content&q={query}", ["zh"]),
        item("douban", "豆瓣", "ph:books", "479E64", "https://www.douban.com/search?q={query}", ["db"]),
        item("reddit", "Reddit", "ph:reddit-logo", "E16F3B", "https://www.reddit.com/search/?q={query}", ["r"]),
        item("github", "GitHub", "ph:github-logo", "657083", "https://github.com/search?q={query}", ["gh"]),
        item("wikipedia", "维基百科", "ph:book-open-text", "64748B", "https://zh.wikipedia.org/w/index.php?search={query}", ["wiki"]),
        item("duckduckgo", "DuckDuckGo", "ph:binoculars", "D88949", "https://duckduckgo.com/?q={query}", ["ddg"]),
        item("maps", "Apple 地图", "ph:map-pin", "51A078", "https://maps.apple.com/?q={query}", ["map"]),
        item("weibo", "微博", "ph:rss", "DC8546", "https://s.weibo.com/weibo?q={query}", ["wb"])
    ]

    static let translation: [SearchTarget] = [
        SearchTarget(
            id: "translate-google-gtx",
            name: "Google 翻译",
            symbol: "ph:google-logo",
            tintHex: "4285F4",
            template: "",
            aliases: ["gt", "gtr"],
            kind: .translator,
            translator: TranslationConfiguration(
                engine: .http,
                openAI: nil,
                http: HTTPTranslationConfiguration(
                    method: "GET",
                    url: "https://translate.googleapis.com/translate_a/single?client=gtx&sl={from}&tl={to}&dt=t&dj=1&q={text}",
                    headers: [:],
                    bodyEncoding: .none,
                    bodyTemplate: "",
                    responseJSONPath: "$.sentences[*].trans"
                ),
                credentialID: nil,
                autoRun: true
            )
        ),
        SearchTarget(
            id: "translate-deeplx",
            name: "DeepLX",
            symbol: "ph:translate",
            tintHex: "0F2B46",
            template: "",
            aliases: ["dlx"],
            kind: .translator,
            translator: TranslationConfiguration(
                engine: .http,
                openAI: nil,
                http: HTTPTranslationConfiguration(
                    method: "POST",
                    url: "https://your-deeplx.example/translate",
                    headers: [:],
                    bodyEncoding: .json,
                    bodyTemplate: #"{"text":"{text}","source_lang":"{from}","target_lang":"{to}"}"#,
                    responseJSONPath: "$.data"
                ),
                credentialID: nil,
                autoRun: false
            )
        ),
        SearchTarget(
            id: "translate-deepl-api",
            name: "DeepL API",
            symbol: "ph:translate",
            tintHex: "0F2B46",
            template: "",
            aliases: ["deepl"],
            kind: .translator,
            translator: TranslationConfiguration(
                engine: .http,
                openAI: nil,
                http: HTTPTranslationConfiguration(
                    method: "POST",
                    url: "https://api.deepl.com/v2/translate",
                    headers: ["Authorization": "DeepL-Auth-Key {credential}"],
                    bodyEncoding: .json,
                    bodyTemplate: #"{"text":["{text}"],"target_lang":"{to}"}"#,
                    responseJSONPath: "$.translations[0].text"
                ),
                credentialID: "translator.deepl",
                autoRun: false
            )
        ),
        SearchTarget(
            id: "translate-microsoft",
            name: "Microsoft Translator",
            symbol: "ph:windows-logo",
            tintHex: "2D7D9A",
            template: "",
            aliases: ["ms", "mst"],
            kind: .translator,
            translator: TranslationConfiguration(
                engine: .http,
                openAI: nil,
                http: HTTPTranslationConfiguration(
                    method: "POST",
                    url: "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to={to}",
                    headers: ["Ocp-Apim-Subscription-Key": "{credential}"],
                    bodyEncoding: .json,
                    bodyTemplate: #"[{"Text":"{text}"}]"#,
                    responseJSONPath: "$[0].translations[0].text",
                    languageMap: ["zh": "zh-Hans", "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant"]
                ),
                credentialID: "translator.microsoft",
                autoRun: false
            )
        ),
        SearchTarget(
            id: "translate-kagi-web",
            name: "Kagi Translate",
            symbol: "ph:sparkle",
            tintHex: "7C5CE7",
            template: "https://translate.kagi.com/?text={query}",
            aliases: ["kagi", "kt"],
            kind: .link
        )
    ]

    static var all: [SearchTarget] { search + translation }
    static var initial: [SearchTarget] { Array(search.prefix(6)) }

    static func category(of target: SearchTarget) -> String {
        translation.contains(where: { $0.id == target.id }) ? "翻译" : "搜索"
    }

    static func subtitle(for target: SearchTarget) -> String {
        switch target.id {
        case "translate-google-gtx": return "免 Key · 非官方 GTX 接口"
        case "translate-deeplx": return "自建实例 · 免 Key"
        case "translate-deepl-api": return "官方 API · 需要 Key（Endpoint 可编辑）"
        case "translate-microsoft": return "Azure F0 可免费 · 需要 Key"
        case "translate-kagi-web": return "网页预填 · 需要 Kagi 账号/额度"
        default: return target.kind == .translator ? (target.translatorDetail ?? "翻译引擎") : "搜索链接"
        }
    }

    static func badges(for target: SearchTarget) -> [String] {
        switch target.id {
        case "translate-google-gtx": return ["免 Key", "非官方"]
        case "translate-deeplx": return ["自建", "免 Key"]
        case "translate-deepl-api": return ["API Key"]
        case "translate-microsoft": return ["F0", "API Key"]
        case "translate-kagi-web": return ["网页"]
        default: return []
        }
    }

    private static func item(_ id: String, _ name: String, _ symbol: String, _ tint: String, _ template: String, _ aliases: [String], _ quick: Bool = false) -> SearchTarget {
        SearchTarget(id: id, name: name, symbol: symbol, tintHex: tint, template: template, aliases: aliases, quickAccess: quick)
    }
}
