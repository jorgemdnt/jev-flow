import Foundation
import Testing
@testable import KeptCore

@Test func dismissDeletesThatTakeWav() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("kept-takes-\(UUID().uuidString)", isDirectory: true)
    let store = TakeStore(directory: root)
    let id = UUID()
    let wav = store.wavURL(id: id)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("RIFF".utf8).write(to: wav)
    try store.save([Take(id: id, wavPath: wav.path, rawTranscript: "auth stays", durationSeconds: 1.2)])

    let remaining = try store.dismiss(id: id)

    #expect(remaining.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: wav.path))
    try FileManager.default.removeItem(at: root)
}

@Test func takeIndexWithoutInsertedTextStillLoads() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("kept-takes-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    let json = """
    [{"id":"\(id.uuidString)","wavPath":"/tmp/kept.wav","rawTranscript":"A agreed","durationSeconds":600}]
    """
    try json.write(to: root.appendingPathComponent("index.json"), atomically: true, encoding: .utf8)

    let takes = try TakeStore(directory: root).load()

    #expect(takes.count == 1)
    #expect(takes[0].id == id)
    #expect(takes[0].rawTranscript == "A agreed")
    #expect(takes[0].durationSeconds == 600)
    #expect(takes[0].insertedText == nil)
}
