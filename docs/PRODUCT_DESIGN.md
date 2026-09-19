# MyResearch 产品设计文档

版本：1.1 · 2026-09-19 · 实施基线，实际构建与测试结果见对应 GitHub Actions。

## 1. 定位与依据

原生 iOS 单手搜索启动器。主路径是「点主屏幕图标 → 键盘自动出现 → 输入 → 一次点击选择搜索词和目标」。不是聚合搜索结果浏览器，也不以分享扩展或 AI 为中心。

依据用户在旧手机实际操作 OneSearch / Lookup 后的描述；口述优先于旧宣传图。不复制原应用商标、图标、二进制或私有资源。首要目标：原词位置稳定，打开直接输入，搜索源完全由用户维护。

## 2. 范围

P0：自动键盘、跟手布局、固定原词、二维搜索、手动排序来源列表、可切换或关闭的联想、链接 CRUD/预设/启停、`{query}` 模板、Trigger 多别名、JSON 导入导出、本地可关闭历史。

P1：快速搜索扩展（1.1 完善接收文字、复用配置、外部跳转和网页兜底）、深色模式和无障碍。

不做：随意点外卖、出去玩。暂不做：AI 对话、翻译服务、Widget、Spotlight、iCloud。背部双击与获取 App 图标捷径不包装成应用独有功能。动作链接仅保留无占位符固定 URL，不做复杂工作流。

## 3. 信息架构与首页

三个页签「搜索 / 我的链接 / 设置」。键盘展开时隐藏页签，顶部收键盘按钮恢复页签；编辑或设置页不抢焦点。

```text
MyResearch                         收键盘
搜索到
  Google                       g    ↗
  哔哩哔哩                     b    ↗
  小红书                       xhs  ↗
  ……可独立滚动的来源列表
联想 · Bing
  春莱布年龄                 [G][B][红]
  春莱布性别                 [G][B][红]
  ……可滚动的候选
原词 春莱布                  [G][B][红]  ← 独立固定
[ 搜索内容…             粘贴 清空 搜索 ] ← 键盘上方
                 系统键盘
```

原词不进入联想数组，不进入候选 ScrollView。候选从 0→1→8、超时、旧请求晚回、重复过滤、加载状态变化均不得改变原词相对键盘坐标。只随键盘、安全区或用户布局模式变化。目标区与候选区各自有高度和滚动空间，不因联想把全部目标挤走。小屏或横屏先压缩滚动区，不裁原词和输入框；使用系统安全区而不是硬编码键盘高度。

### 点击语义

普通关键词：目标列表使用当前词，候选正文走默认来源，右侧按钮走指定来源。`b 春莱布` 或 `春莱布 b` 完整匹配别名后提示目标为哔哩哔哩，传给目标的词去掉 Trigger；右侧按钮仍能覆盖目标。

键盘搜索：有 Trigger 用指定来源，否则默认来源。单独一个 `b` 不是空查询。闪电表示少一次选择，不是输入每个字就离开 App；仅明确提交、点击才执行。中文／日文 marked text 期间不发联想、不解析提交、不覆盖组词；提交后刷新。

返回 App 保留关键词，方便换来源；清空恢复空态。不自动读剪贴板，只有显式粘贴读取。无关键词可显示本地历史；搜索型来源禁止空查询，固定动作可以打开。

### 联想

远端完全等于原词的建议去重，不重新把原词插到顶部。按引擎顺序显示。点正文搜索，小箭头仅填入继续编辑。

约 250ms 防抖、取消前次任务、响应世代校验、短超时和内存缓存。断网、限流或解析失败退为本地历史及状态提示，不假造建议、不阻碍原词。关闭、清空或换引擎后旧结果不回填。

默认 Bing；可选 Google、仅本地历史或关闭。开启联网联想会向对应第三方发送关键词，设置明确说明。公开联想端点不保证稳定、无 SLA；使用临时会话。无账户、自建服务器或遥测。

## 4. 我的链接

名称、图标、Trigger 概览、启停；编辑按钮及拖拽把手手动排序。顺序同时控制首页与快捷按钮，不根据使用次数偷偷重排。

新增分预设／自定义。预设保存为可编辑普通记录，不被后台覆盖；重复添加提示。字段包括名称、图标符号与颜色、URL 模板、可选 HTTPS 兜底、多个 Trigger、启用、是否在候选右侧显示。右侧最多三个已启用且勾选的来源，顺序跟随人工排序，其余仍可从主页使用。

```text
https://www.google.com/search?q={query}
exampleapp://search?keyword={query}&tab=all
https://example.com/find/{query}/details
```

每个 `{query}` 使用 UTF-8 百分号编码替换，仅 RFC3986 unreserved 字符保留。`& + # ? /`、中文和 emoji 不得逃逸为参数，不再整体二次编码。无不安全原样插入默认模式。

编辑器提供测试关键词、生成 URL 预览、测试打开。校验名称、scheme、空白、未知占位符、长度、重复 Trigger 与跨来源冲突。禁止 javascript/data/file 与递归自身链接；网页需要主机，兜底只允许 HTTPS。无占位符提示固定动作，不携关键词。

预设网页有效不等于原生 Scheme 已真机测试。Universal Links 由系统和目标 App 决定，自定义 Scheme 失败后仅试一次 HTTPS 兜底，最终失败反馈可复制链接、不循环。

## 5. 设置与持久化

自动键盘、跟手、闪电默认开；可选默认来源、联想引擎、候选数、历史开关。排序在我的链接管理，不加智能重排。

本地 JSON 原子写入；导出链接与设置不含历史。导入先校验版本、重复 ID、别名冲突和模板，展示数量并确认后整体替换，替换前保留旧文件备份。坏文件保留，不静默覆盖；写入失败显示错误。清空历史单独确认。

跨设备迁移用导入导出。不要求 iCloud / App Groups；不存 Apple ID、签名证书或 API 密钥。

## 6. 快速搜索扩展（1.1）

路径：选中文字 → 分享 → MyResearch → 点来源或候选右侧按钮 → 尝试打开目标 App／系统浏览器。不是只提供 WKWebView 的网页搜索器；网页搜索保留为明确后备。输入可编辑，具备联想、Trigger、默认来源、固定原词、三个快捷来源。首次不抢键盘，用户点击才编辑。

读取优先级：Safari 选区 → 共享文字／富文本 → 页面 URL。Selection.js 只读取选区与页面地址，不读正文。多附件稳定读取，单个失败继续尝试，单项 1 秒及总计 5 秒超时。最多 4096 字符并提示截断，开始编辑后忽略晚回结果。

主 App 首次打开和配置保存后发布经过校验的共享钥匙串快照，不共享历史。主 App 与扩展签名要求相同首个 keychain-access-groups，不用 App Groups、iCloud 或服务器。扩展成功读取才显示「已同步主 App」，不能把主 App 写入成功当成扩展可读。重签分组被拆开时明确未同步，提供 `myresearch://share?q=…` 接力到主 App，免重新输入；JSON 导入仍可后备且先确认，不改主 App。

自签版默认兼容跳转：先 NSExtensionContext.open，失败后通过 responder chain 的 UIApplication 实例使用现代 open(_:options:completionHandler:)。不使用废弃 openURL:、私有 selector 或 UIApplication.shared。**不是 Apple 对分享扩展的保证，不宣称通过 App Store 审核或覆盖所有系统及宿主。** 只有成功回调才完成扩展，失败保留输入和恢复操作。成功交给系统也不代表第三方正确理解搜索 URL。

长按来源可以扩展内网页搜索／复制链接。扩展不读主 App 历史；仅本地历史模式不会展示主 App 历史。联网联想遵循主 App 设置和同样隐私说明。

完整包包含扩展，core 不含，主 Bundle ID 相同。LiveContainer 不保证注册客体系统扩展，本功能应独立签名安装完整包。详见 SHARE_EXTENSION.md 和 Signing/。

## 7. 技术与交付

iOS17+，SwiftUI + 必要 UIKit 输入控件。纯 Foundation 核心支持 Linux/macOS 单元测试。无第三方运行时包，脚本确定生成 Xcode 工程。

Core：模板、Trigger、模型、校验、候选、分享输入和接力；App：界面、存储、联想；Shared：共享钥匙串；Share：分享 UI、输入读取、外部打开与网页；ShareProbe：独立测试目标，不进入 IPA；Tests/UITests：核心与系统分享测试。

Actions 用 macOS/Xcode 编译真实 iphoneos arm64、禁用签名，打包 Payload/MyResearch.app 为 IPA，附 SHA256 与构建元数据。不把模拟器 .app 冒充 IPA，不上传证书。交付设计文档、代码、测试、工作流、安装说明、完整/core 未签名 IPA、Signing 模板及可追溯日志。

提交不等于编译通过，编译通过不等于所有第三方 App 真机兼容。未签名包需用户签名工具，同时签主应用与扩展。

## 8. 验收

|编号|场景|要求|
|---|---|---|
|A01|冷启动|键盘出现，直接输入|
|A02|异步联想增减|原词独立固定不移动|
|A03|原词／右侧来源|默认与明确来源区别正确，一次打开|
|A04|候选正文／填入|正文搜索，箭头只填入|
|A05|Trigger|前后缀、大小写、完整边界、去掉触发词|
|A06|输入法组词|不误交、不覆盖、不发未提交内容|
|A07|保留字符和 emoji|编码完整，无参数注入|
|A08|网络失败／旧请求|不回填过期内容，不阻塞原词|
|A09|编辑排序后重启|顺序和启停持久|
|A10|默认目标被删除|回落启用来源，全关时有可操作空态|
|A11|错误 JSON|拒绝，原配置不变|
|A12|导入导出|保留配置，不泄漏历史|
|A13|深色／横屏／大字|原词和输入可达，44pt 点击区|
|A14|未安装目标|一次兜底，失败明确|
|A15|真实系统分享|实际 .appex 接收文字而非错取 URL，读到主 App 自定义来源|
|A16|跨 App 搜索|真实打开独立测试 App，收到准确原词／去掉 Trigger 的词，快捷按钮覆盖默认|
|A17|分享失败|扩展不消失，原文仍在并有恢复按钮|
|A18|IPA|真实 arm64、无签名资料、校验值可复验|

以对应 Actions 结果标记通过。模拟器不代替实体机、Safari 选区来源差异、中文输入细节或第三方 Scheme 的真实验收。

## 9. 工程依据

- Apple 扩展生命周期和受限 API：https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html
- Apple Safari 预处理及容器共享：https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html
- Apple 跨 App 共享钥匙串：https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps
- GitHub 构建产物：https://docs.github.com/en/actions/tutorials/store-and-share-data
- macOS runner：https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md
