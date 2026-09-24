import Foundation
import KeptCore
import Security

enum SecretKeychain {
    static func save(_ secret: String, account: String) -> Bool {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        delete(account: account)
        let query = KeychainQuery.save(account: account, secret: Data(trimmed.utf8))
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(account: String) -> String? {
        let query = KeychainQuery.load(account: account)
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8),
              !text.isEmpty else { return nil }
        return text
    }

    static func delete(account: String) {
        SecItemDelete(KeychainQuery.delete(account: account) as CFDictionary)
    }
}
