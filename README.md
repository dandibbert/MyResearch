# MyResearch

原生 iOS 单手搜索启动器。**打开就输入，原词始终在手边。**

[产品设计文档](docs/PRODUCT_DESIGN.md) · [安装与构建](docs/INSTALL.md) · [分享扩展](docs/SHARE_EXTENSION.md) · [GitHub Actions](../../actions/workflows/ios.yml)

## 1.1

三个页签：搜索 / 我的链接 / 设置。自动弹出键盘；跟手输入框；独立固定原词行；候选正文 + 多搜索源按钮；Bing/Google/本地/关闭联想；`{query}` 模板、前后缀 Trigger、HTTPS 兜底；手动排序、预设、启停；本地历史及 JSON 导入导出。

分享扩展现支持文字优先读取、可编辑输入、联想和固定原词、Trigger、逐词多来源按钮；主 App 配置经共享钥匙串自动复用。点击来源优先尝试目标 App／系统浏览器，失败保留文字并提供网页搜索或主 App 接力。兼容跳转不是 Apple 保证的扩展能力；重签必须保留两个目标相同的钥匙串组才能自动共享配置。

不包含外卖随机、出去玩、AI 对话或 iCloud 同步。

## 获取 IPA

Actions → **iOS · unsigned IPA** → 对应提交 → Artifacts → `MyResearch-unsigned-IPA`。

内含 `MyResearch-unsigned.ipa`（含扩展）、`MyResearch-core-unsigned.ipa`（不含扩展）、SHA-256、构建元数据、产品文档与 Signing 说明。源代码提交不表示构建成功；以对应运行结果与产物为准。未签名包需要自行签名安装，测试分享扩展请安装完整包。

## 开发

iOS 17+，SwiftUI + UIKit，纯 Foundation 核心，无第三方运行时依赖。

```sh
python3 Scripts/make_project.py
open MyResearch.xcodeproj
swift test
```

`Core/` 搜索与配置，`App/` 主界面和存储，`Shared/` 共享钥匙串，`Share/` 扩展，`Tests/` 单元测试，`UITests/` 真实系统分享流程测试，`ShareProbe/` 模拟器测试用的独立目标 App（不进入 IPA），`Scripts/` 工程生成与设备打包。

## 隐私与边界

无服务器、账户或遥测。联网联想会把关键词发送至所选提供方，可关闭。导出配置和共享钥匙串不包含历史。扩展浏览使用临时网页存储。Safari 预处理只读取选区和页面地址，不读取网页全文。

第三方 App 是否接管链接及其 URL Scheme 需真机核对。不依赖 App Groups 或 iCloud；扩展自动共享依赖相同 keychain-access-groups。变更签名团队、Bundle ID 或安装工具前先导出配置。LiveContainer 不保证注册客体 App 的系统分享扩展。
