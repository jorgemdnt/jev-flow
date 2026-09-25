import Darwin
import Foundation

/// The TypeSafe key. The data protection keychain needs `keychain-access-groups`,
/// and that entitlement is restricted: an ad-hoc signature cannot carry it, so
/// the process is killed. The login keychain asks for the login password after
/// a resign. This file is mode 0600 under Application Support instead.
public enum SecretFile {
    public static func save(_ secret: String, account: String, directory: URL) -> Bool {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = fileURL(account: account, directory: directory) else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return false
        }
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        let fd = open(url.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        let data = Data(trimmed.utf8)
        let written = data.withUnsafeBytes { bytes -> Int in
            guard let base = bytes.baseAddress else { return -1 }
            return Darwin.write(fd, base, bytes.count)
        }
        guard written == data.count else {
            try? FileManager.default.removeItem(at: url)
            return false
        }
        return true
    }

    public static func load(account: String, directory: URL) -> String? {
        guard let url = fileURL(account: account, directory: directory),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func delete(account: String, directory: URL) {
        guard let url = fileURL(account: account, directory: directory) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    public static func permissions(account: String, directory: URL) -> Int? {
        guard let url = fileURL(account: account, directory: directory),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let mode = attributes[.posixPermissions] as? Int else { return nil }
        return mode & 0o777
    }

    private static func fileURL(account: String, directory: URL) -> URL? {
        guard account.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return nil }
        return directory.appendingPathComponent("\(account).key")
    }
}
