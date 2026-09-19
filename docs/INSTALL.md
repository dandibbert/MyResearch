# 安装与验证

## 选择 IPA

`MyResearch-unsigned.ipa` 是主 App + 快速搜索分享扩展；签名工具必须一起签名嵌入的扩展。`MyResearch-core-unsigned.ipa` 是同一主 App 去除扩展的版本。

两个包使用相同 Bundle ID，是替代安装而非可并存版本。Actions 的外层 artifact ZIP 不是 IPA，解压后选择其中 `.ipa`。这些是真机 arm64 未签名产物，需要自己的签名／安装工具处理；不需要向 GitHub 上传 Apple 账号、p12 或 mobileprovision。

LiveContainer 不保证系统注册客体 App 的分享扩展。测试分享应独立安装完整包。没有 iCloud / App Groups 权益；完整包为配置共享声明共同钥匙串组。变更签名团队或 Bundle ID 前先导出配置，不保证跨团队覆盖保留数据。

## 首次使用

主 App 自动弹出键盘；原词固定在输入框上方。点正文使用默认来源，右侧按钮指定来源，上方来源列表同样直接搜索。设置可选 Bing、Google、本地历史或关闭联想。

右上角收键盘后显示三个页签。在「我的链接」添加预设或 `{query}` 自定义模板，编辑拖拽排序。勾选「候选右侧」的前三个启用来源作为快捷按钮。`b 关键词` 或 `关键词 b` 后提交使用哔哩哔哩。

预设以网页链接为主；URL Scheme 和 Universal Links 是否由第三方 App 接管需真机确认。可自行设置原生 Scheme 和 HTTPS 兜底。

## 分享扩展

签名安装完整包，包含 MyResearch.app 和其中 MyResearchShare.appex。先打开主 App 一次，再从其他 App 选中文字 → 分享 → MyResearch → 点击目标。点来源或右侧快捷按钮优先尝试外部搜索，长按来源可改为扩展内网页搜索。输入可编辑，原词不随联想移动。

看到「已同步主 App」时，来源、排序、启停、默认目标、Trigger 和联想设置均来自主 App。两个目标必须拥有相同的首个 keychain-access-groups；相同证书并不自动意味着相同分组。交付包 Signing/ 有说明与模板。若分组被重签工具改写，扩展会显示未同步，可点「在主 App 中选择我的来源」携带文字接力，不必重新输入；也可导入 JSON。

兼容跳转不是 Apple 为分享扩展保证的功能，可能被系统或宿主阻止。只有成功回调才关闭扩展，失败保留文字并提供恢复按钮。设置中的「测试分享扩展」可以直接调出系统分享菜单检查。

## 自己构建

macOS、Xcode 16.4 或兼容新版本、Python 3。无第三方包安装步骤。

```sh
python3 Scripts/make_project.py
swift test
xcodebuild -project MyResearch.xcodeproj -scheme MyResearch \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData ARCHS=arm64 \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build
python3 Scripts/package_ipa.py
```

产物在 dist/。SHA256SUMS.txt 可验真，build-info.json 记录 commit、SDK、Xcode、版本。主 Bundle ID 是 com.dandibbert.MyResearch。

## 验证边界

Actions 保存单元测试和真实模拟器分享流程日志。第三方 App 深链、实体机中文组合输入、各签名工具权限保留与实体机手感仍需验证。模拟器通过不代表所有设备均通过。网络联想接口没有可用性保证，断网不影响原词操作。
