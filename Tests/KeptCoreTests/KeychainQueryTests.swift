import Foundation
import Testing
@testable import KeptCore

@Test func aSavedKeyIsReadableOnlyByThisUser() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    #expect(SecretFile.save("  secret  ", account: "typesafe", directory: directory))
    #expect(SecretFile.load(account: "typesafe", directory: directory) == "secret")
    #expect(SecretFile.permissions(account: "typesafe", directory: directory) == 0o600)
    SecretFile.delete(account: "typesafe", directory: directory)
    #expect(SecretFile.load(account: "typesafe", directory: directory) == nil)
}

@Test func anEmptyKeyIsNotSaved() {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    #expect(SecretFile.save("   ", account: "typesafe", directory: directory) == false)
    #expect(SecretFile.save("secret", account: "../typesafe", directory: directory) == false)
}

@Test func typeSafeEnvReadsTheKeyAndSkipsComments() {
    let text = """
    # TYPESAFE_API_KEY=nope
    OTHER=1
    TYPESAFE_API_KEY="abc"
    """
    #expect(TypeSafeEnv.key(in: text) == "abc")
    #expect(TypeSafeEnv.key(in: "TYPESAFE_API_KEY=\n") == nil)
}
