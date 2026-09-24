import Foundation

public struct Take: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let wavPath: String
    public let rawTranscript: String
    public let durationSeconds: Double
    public var insertedText: String?

    public init(
        id: UUID,
        wavPath: String,
        rawTranscript: String,
        durationSeconds: Double,
        insertedText: String? = nil
    ) {
        self.id = id
        self.wavPath = wavPath
        self.rawTranscript = rawTranscript
        self.durationSeconds = durationSeconds
        self.insertedText = insertedText
    }
}

public struct TakeStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func wavURL(id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).wav")
    }

    public func load() throws -> [Take] {
        let index = indexURL
        guard FileManager.default.fileExists(atPath: index.path) else { return [] }
        return try JSONDecoder().decode([Take].self, from: Data(contentsOf: index))
    }

    public func save(_ takes: [Take]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(takes).write(to: indexURL, options: .atomic)
    }

    /// Deletes that take's wav if it sits in this store. Leaves every other file alone.
    public func dismiss(id: UUID) throws -> [Take] {
        var takes = try load()
        guard let index = takes.firstIndex(where: { $0.id == id }) else { return takes }
        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        let wav = URL(fileURLWithPath: takes[index].wavPath).resolvingSymlinksInPath().standardizedFileURL
        if wav.deletingLastPathComponent().path == root.path,
           FileManager.default.fileExists(atPath: wav.path) {
            try FileManager.default.removeItem(at: wav)
            let sidecar = wav.deletingPathExtension().appendingPathExtension("txt")
            if FileManager.default.fileExists(atPath: sidecar.path) {
                try FileManager.default.removeItem(at: sidecar)
            }
        }
        takes.remove(at: index)
        try save(takes)
        return takes
    }

    private var indexURL: URL {
        directory.appendingPathComponent("index.json")
    }
}

public enum KeptPaths {
    public static var applicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kept", isDirectory: true)
    }

    public static var modelsDirectory: URL {
        applicationSupport.appendingPathComponent("models", isDirectory: true)
    }

    public static var takesDirectory: URL {
        applicationSupport.appendingPathComponent("takes", isDirectory: true)
    }
}
