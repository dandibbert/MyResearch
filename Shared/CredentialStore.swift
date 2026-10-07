import Foundation
import Security

enum SharedCredentialStore {
    private static let service = "com.dandibbert.MyResearch.translation-credentials.v1"

    static func value(for id: String) throws -> String? {
        guard valid(id) else { throw CredentialStoreError.invalidID }
        var query = lookup(id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw CredentialStoreError.keychain(status)
        }
        return value
    }

    static func set(_ value: String, for id: String) throws {
        guard valid(id) else { throw CredentialStoreError.invalidID }
        if value.isEmpty { try delete(id); return }
        let data = Data(value.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updated = SecItemUpdate(lookup(id) as CFDictionary, attributes as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw CredentialStoreError.keychain(updated) }
        var item = lookup(id)
        attributes.forEach { item[$0.key] = $0.value }
        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecSuccess else { throw CredentialStoreError.keychain(added) }
    }

    static func delete(_ id: String) throws {
        guard valid(id) else { throw CredentialStoreError.invalidID }
        let status = SecItemDelete(lookup(id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychain(status)
        }
    }

    static func contains(_ id: String) -> Bool {
        (try? value(for: id)) != nil
    }

    private static func lookup(_ id: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
        ]
    }

    private static func valid(_ id: String) -> Bool {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 200 && !trimmed.contains("\n") && !trimmed.contains("\r")
    }
}

private enum CredentialStoreError: LocalizedError {
    case invalidID
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidID: return "Credential ID 无效。"
        case .keychain(let status): return "翻译密钥钥匙串不可用（\(status)）。请确认主 App 与分享扩展保留同一 keychain-access-group。"
        }
    }
}
