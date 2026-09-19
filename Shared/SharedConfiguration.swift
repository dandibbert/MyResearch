import Foundation
import Security

/// Both targets request the same first keychain-access-group when signed.
/// Re-signers may replace entitlements; missing data is NOT reported as synced.
enum SharedConfiguration {
    static let service = "com.dandibbert.MyResearch.shared-configuration.v1"
    private static var lookup: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: "configuration"]
    }
    static func publish(_ configuration: Configuration) throws {
        try ConfigurationCodec.validate(configuration)
        let data = try JSONEncoder().encode(ConfigurationSnapshot(configuration: configuration))
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let updated = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw failure(updated) }
        var item = lookup
        attributes.forEach { item[$0.key] = $0.value }
        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecSuccess else { throw failure(added) }
    }
    static func read() throws -> ConfigurationSnapshot? {
        var query = lookup
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw failure(status) }
        return try ConfigurationSnapshot.decode(data)
    }
    private static func failure(_ status: OSStatus) -> ResearchError {
        ResearchError("共享配置不可用（钥匙串 \(status)）。签名工具需为主 App 和分享扩展保留同一钥匙串组；也可使用主 App 接力或导入配置。")
    }
}
