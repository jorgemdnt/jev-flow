import Foundation
import Security
import Testing
@testable import KeptCore

@Test func keychainQueryStaysOffTheLoginKeychain() {
    let load = KeychainQuery.load(account: "typesafe")
    let save = KeychainQuery.save(account: "typesafe", secret: Data("not-a-real-key".utf8))
    let delete = KeychainQuery.delete(account: "typesafe")
    for query in [load, save, delete] {
        #expect(query[kSecAttrService as String] as? String == "JevFlow")
        #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true)
        #expect(query[kSecAttrService as String] as? String != "local.kept.app")
    }
    #expect(KeychainQuery.service != "local.kept.app")
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
