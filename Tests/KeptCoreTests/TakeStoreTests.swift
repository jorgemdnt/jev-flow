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
