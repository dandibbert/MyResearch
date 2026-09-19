# MyResearch

原生 iOS 单手搜索启动器。**打开就输入，原词始终在手边。**

[产品设计文档](docs/PRODUCT_DESIGN.md) · [安装与构建](docs/INSTALL.md) · [GitHub Actions](../../actions/workflows/ios.yml)

## 这一版

三个页签：搜索 / 我的链接 / 设置。自动弹出键盘；跟手输入框；独立固定的原词行；候选正文 + 多搜索源按钮；可切换或关闭的 Bing/Google 联想；可自定义的 `{query}` 模板、前后缀 Trigger、HTTPS 兜底；手动排序、预设、启停；本地历史与 JSON 配置导入导出。

不包含外卖随机、出去玩、AI 对话或伪造的 iCloud 同步。分享扩展是辅助入口：扩展内网页搜索，独立配置可手动导入；不是原版任意 App 跳转的等价实现。详细约束在产品文档中。

## 获取 IPA

打开 Actions → **iOS · unsigned IPA** → 选对应提交 → Artifacts → `MyResearch-unsigned-IPA`。

内含 `MyResearch-unsigned.ipa`（含扩展）、`MyResearch-core-unsigned.ipa`（不含扩展）、SHA-256、构建元数据和说明。必须等该提交的设备构建成功且出现 artifact；源代码提交本身不表示构建已通过。未签名包需要自行签名安装。

## 开发

iOS 17+，SwiftUI + UIKit，纯 Foundation 核心。无第三方运行时依赖，也不需要 XcodeGen、CocoaPods 或远程 Swift Package。

```sh
python3 Scripts/make_project.py  # 原生工程、Info.plist 与原创图标
open MyResearch.xcodeproj
swift test                     # 核心逻辑也可在 Linux 测试
```

目录：`Core/` 搜索与配置逻辑，`App/` 原生界面和存储，`Share/` 分享扩展，`Tests/` 单元测试，`UITests/` 模拟器交互验收，`Scripts/` 工程生成与真实设备 IPA 打包。

## 隐私及限制

无自建服务器、无遥测。启用联网联想时关键词会发送至所选提供方；可切换本地/关闭。搜索链接由用户明确点击才打开。导出的配置不包含历史。使用 `.ephemeral` 联想会话与扩展内临时网页存储。

网页预设可编辑；第三方 App 是否接管链接以及自定义 Scheme 是否仍有效需在真机核对。不依赖 App Groups 或 iCloud 签名权益。请先备份配置，再变更安装工具、签名团队或 Bundle ID。
