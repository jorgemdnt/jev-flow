import Foundation
import Security

/// Login-keychain items prompt for the login password, and Always Allow does
/// not survive an ad-hoc resign. The key stays in the data protection keychain
/// under `JevFlow`. Never query `local.kept.app`.
public enum KeychainQuery {
    public static let service = "JevFlow"

    public static func save(account: String, secret: Data) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: service,
            kSecValueData as String: secret,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    public static func load(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    public static func delete(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }
}

public enum TypeSafeEnv {
    public static func key(in text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let row = line.trimmingCharacters(in: .whitespaces)
            guard !row.hasPrefix("#") else { continue }
            guard row.hasPrefix("TYPESAFE_API_KEY=") else { continue }
            var value = String(row.dropFirst("TYPESAFE_API_KEY=".count))
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}
