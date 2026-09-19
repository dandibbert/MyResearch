# 完整 IPA 的配置自动共享

不需要把证书、密码、Apple 账号或 mobileprovision 上传仓库。

主 App 与扩展都要签名；共享配置还要求两者的第一个 `keychain-access-groups` **完全相同**，例如 `ABCDE12345.com.dandibbert.MyResearch.shared`。

前缀来自自己的 provisioning profile 的 ApplicationIdentifierPrefix，不应猜测，也不一定等于 Team ID。替换模板中的 YOUR_APP_IDENTIFIER_PREFIX。profile 必须授权该 group 或匹配的通配符；只修改 entitlement 并不能获得权限。

模板仅展示需合并进两个目标各自 entitlements 的共享部分。主 App 和扩展仍需各自正确的 application-identifier、bundle ID 与签名；不要给两个不同 target 盲目套用同一份完整签名资料。没有 App Groups / iCloud 要求。

部分重签工具会把每个目标的组改成各自 Bundle ID，导致共享不可用。签好先打开主 App 一次，然后在真实分享扩展里看到「已同步主 App」才算成功。主 App 的「已写入」只证明自身可写，不能证明扩展可读。

无法保留分组时，扩展的「在主 App 中选择我的来源」可携带当前文字接力；JSON 导入是另一个后备。没有共享权限不得闪退、清空主 App 配置或宣称已同步。
