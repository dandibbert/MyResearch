# 安装与验证

## 选择 IPA

- `MyResearch-unsigned.ipa`：主 App + 快速搜索分享扩展。签名工具必须一起签名嵌入的扩展。
- `MyResearch-core-unsigned.ipa`：同一主 App，去除了扩展；用于不需要分享扩展或容器式运行的场景。

两个包使用相同 Bundle ID，是替代安装而非可并存版本。下载 GitHub Actions 的 `MyResearch-unsigned-IPA` artifact 并解压后选择 `.ipa`；外层 artifact ZIP 不是 IPA。

这些是真机 arm64、未签名产物，不是可直接点安装的 App Store 包。使用自己现有的签名/安装工具处理后安装；本项目不需要把 Apple 账号、p12 或 mobileprovision 上传 GitHub。不同签名工具、证书或容器的安装效果尚需真机验证。

LiveContainer 不保证系统注册客体 App 的分享扩展；使用 core 包可避免对系统扩展的依赖。没有申请 iCloud、App Groups 或特殊权限。更换签名团队或 Bundle ID 不保证覆盖保留旧数据；先导出配置。

## 第一次打开

首页自动弹出键盘。输入关键词后，下方高亮「原词」固定在输入框上方。点正文使用默认来源，点旁边图标使用指定来源；上方来源列表同样可以直接搜索。联想来自 Bing，可在设置切换 Google、仅本地历史或关闭。

点右上角键盘按钮收起键盘，底部会出现「搜索 / 我的链接 / 设置」。在「我的链接」添加预设或自定义 URL，使用 `{query}` 放置关键词。点「编辑」拖拽排序；勾选「候选右侧」的前三个启用来源作为快捷按钮。输入 `b 关键词` 或 `关键词 b` 后按键盘搜索会使用哔哩哔哩。

内置预设以网页链接为主。能否跳到 App 由系统 Universal Links 和目标 App 控制；不代表每一款目标 App 的 URL Scheme 已实测。需要直接跳转时可自行设置 Scheme 与 HTTPS 兜底。

## 分享扩展

完整包安装且扩展被签名/系统注册后，在分享菜单选择 MyResearch。该入口在扩展内打开网页结果，不使用私有方法强行启动外部 App。扩展配置与主 App 隔离：默认使用内置预设；主 App 导出 JSON 后，可在扩展导入。不宣称自动同步或已复现原版跨 App 跳转。

## 自己构建

macOS、Xcode 16.4 或兼容的新版本、Python 3。没有第三方包下载步骤。

```sh
python3 Scripts/make_project.py
open MyResearch.xcodeproj
```

终端编译：

```sh
swift test
xcodebuild -project MyResearch.xcodeproj -scheme MyResearch \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData ARCHS=arm64 \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build
python3 Scripts/package_ipa.py
```

产物在 `dist/`。`SHA256SUMS.txt` 用于校验；`build-info.json` 记录 commit、设备平台、SDK、Xcode 及版本。主应用 Bundle ID 为 `com.dandibbert.MyResearch`。

## 验证边界

核心测试和模拟器测试日志由 Actions 保存；第三方 App 深链、真实中文键盘组合输入、签名安装和实体机手感仍需要真机验证。未执行的项目不等于已通过。网络联想接口不承诺稳定可用；断网不影响固定原词操作。
