# 分享扩展 1.1

## 交互

选中文字 → 系统分享 → MyResearch → 点来源／原词快捷按钮 → 目标 App 或系统浏览器。无需先复制、打开 MyResearch 再粘贴。输入框可编辑收到的文字，默认不抢键盘。联想、默认目标、前后缀 Trigger 复用主 App 设置。原词独立固定，联想刷新不改变它的位置。

长按来源可选择「在扩展内搜索网页」或「复制搜索链接」。未收到成功回调时保留原文并提供恢复操作，不直接消失或假报成功。空输入不打开搜索型链接，固定动作仍可使用。

## 配置

主 App 维护唯一搜索库，每次保存后发布不含历史的快照。共享钥匙串权限正确时，扩展每次打开自动读取来源、顺序、启停、默认目标、Trigger、快捷按钮和联想设置。无账户或服务器。

相同证书不等于相同钥匙串组。重签必须保留两个 target 相同的首个 keychain-access-groups，见 Signing/。扩展显示「已同步主 App」才表示成功。权限被重写时可携文字接力到主 App，不要求先导出再导入；JSON 导入仍是后备。主 App 只接受文字和已有 target ID，不直接执行外部传来的任意 URL；停用或删除的目标不会偷偷换成默认搜索。

## 分享内容

优先 Safari 选区，然后共享纯文本／富文本，最后页面 URL。Safari 脚本只读取 window.getSelection() 和 document.URL，不读取全文或主动上传。多个附件按稳定顺序处理，失败继续尝试。单项读取 1 秒超时，总读取 5 秒超时；最多保留 4096 个用户可见字符并提示截断。编辑开始后忽略晚回内容。

联网联想遵循所选提供方。Bing／Google 会收到关键词，选择本地／关闭则不发送联想请求。扩展不读取主 App 历史，因此「仅本地历史」不会展示主 App 的历史。

## 外部跳转边界

先用 NSExtensionContext.open，失败后自签版默认尝试 responder chain + 现代 UIApplication.open(_:options:completionHandler:)。菜单可以关闭兼容跳转。没有使用 UIApplication.shared、废弃 openURL: 或私有 selector，但从扩展获取应用实例不是 Apple 对分享扩展保证的路径。**不宣称所有 iOS／宿主／签名方式均支持，也不宣称可过 App Store 审核。**

只以打开 completionHandler 的 accepted 作为交给系统成功的依据；这不代表第三方 App 一定把 URL 理解为搜索。网页能否被 Universal Links 转交由系统决定，原生 Scheme 需要目标应用支持。失败保留原词，可选择网页、主 App 接力或复制。

LiveContainer 不保证注册客体分享扩展；测试本功能应独立签名安装完整 IPA。

## 验证方法

单元测试覆盖输入优先级、截断、接力编码、重复参数拒绝和配置快照。模拟器测试用 UIActivityViewController 激活实际安装的 .appex，检查共享配置与选中文字，并用独立测试 App 的自定义 Scheme 接收实际搜索词，不把 SwiftUI 预览当成跨 App 测试。

ShareProbe 是独立测试目标，不进入交付 IPA。截图和日志保存在 Actions；以对应提交结果为准。实体机系统、第三方 Scheme、不同重签工具和 Safari 提供选区的行为仍需真机检查。

## 参考

- Apple App Extension Programming Guide: https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html
- Apple Keychain Sharing: https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps
- Apple Safari preprocessing: https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html
- 现代兼容跳转参考案例（不是 Apple 保证）：https://gist.github.com/Tunous/363bb71baa5b401ff8a63304f6389be5
