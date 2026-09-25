import Foundation
import KeptCore

enum SecretKeychain {
    static func save(_ secret: String, account: String) -> Bool {
        SecretFile.save(secret, account: account, directory: KeptPaths.applicationSupport)
    }

    static func load(account: String) -> String? {
        SecretFile.load(account: account, directory: KeptPaths.applicationSupport)
    }

    static func delete(account: String) {
        SecretFile.delete(account: account, directory: KeptPaths.applicationSupport)
    }
}
