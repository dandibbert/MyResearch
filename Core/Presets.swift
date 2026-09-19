import Foundation

enum Presets {
    static let all: [SearchTarget] = [
        item("google", "Google", "globe", "4285F4", "https://www.google.com/search?q={query}", ["g", "google"], true),
        item("bilibili", "哔哩哔哩", "play.rectangle.fill", "E777A0", "https://search.bilibili.com/all?keyword={query}", ["b", "bili"], true),
        item("xiaohongshu", "小红书", "book.closed.fill", "EB4B65", "https://www.xiaohongshu.com/search_result?keyword={query}", ["xhs"], true),
        item("bing", "Bing", "sparkle.magnifyingglass", "148C95", "https://www.bing.com/search?q={query}", ["bing"]),
        item("baidu", "百度", "pawprint.fill", "405CE1", "https://www.baidu.com/s?wd={query}", ["bd"]),
        item("youtube", "YouTube", "play.rectangle.fill", "E84848", "https://www.youtube.com/results?search_query={query}", ["yt"]),
        item("taobao", "淘宝", "bag.fill", "EB7D32", "https://s.taobao.com/search?q={query}", ["tb"]),
        item("jd", "京东", "shippingbox.fill", "DA4B51", "https://search.jd.com/Search?keyword={query}", ["jd"]),
        item("zhihu", "知乎", "text.bubble.fill", "387CD4", "https://www.zhihu.com/search?type=content&q={query}", ["zh"]),
        item("douban", "豆瓣", "books.vertical.fill", "479E64", "https://www.douban.com/search?q={query}", ["db"]),
        item("reddit", "Reddit", "bubble.left.and.bubble.right.fill", "E16F3B", "https://www.reddit.com/search/?q={query}", ["r"]),
        item("github", "GitHub", "chevron.left.forwardslash.chevron.right", "657083", "https://github.com/search?q={query}", ["gh"]),
        item("wikipedia", "维基百科", "character.book.closed.fill", "64748B", "https://zh.wikipedia.org/w/index.php?search={query}", ["wiki"]),
        item("duckduckgo", "DuckDuckGo", "shield.lefthalf.filled", "D88949", "https://duckduckgo.com/?q={query}", ["ddg"]),
        item("maps", "Apple 地图", "map.fill", "51A078", "https://maps.apple.com/?q={query}", ["map"]),
        item("weibo", "微博", "antenna.radiowaves.left.and.right", "DC8546", "https://s.weibo.com/weibo?q={query}", ["wb"])
    ]
    static var initial: [SearchTarget] { Array(all.prefix(6)) }
    private static func item(_ id: String, _ name: String, _ symbol: String, _ tint: String, _ template: String, _ aliases: [String], _ quick: Bool = false) -> SearchTarget {
        SearchTarget(id: id, name: name, symbol: symbol, tintHex: tint, template: template, aliases: aliases, quickAccess: quick)
    }
}
