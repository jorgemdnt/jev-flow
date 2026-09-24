import AppKit
import Foundation
import KeptCore
import SwiftUI

@MainActor
final class KeptDelegate: NSObject, NSApplicationDelegate {
    let session = Session()
    private var chrome: KeptChrome?

    func applicationDidFinishLaunching(_ notification: Notification) {
        chrome = KeptChrome(session: session)
        chrome?.install()
    }
}

struct KeptApp: App {
    @NSApplicationDelegateAdaptor(KeptDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
        .defaultLaunchBehavior(.suppressed)
    }
}

if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--transcribe" {
    let path = CommandLine.arguments[2]
    let box = TranscribeBox()
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        let started = ContinuousClock.now
        do {
            let text = try await ParakeetEngine.shared.transcribe(wavPath: path, languageCode: SpokenLanguage.auto.code)
            let elapsed = ContinuousClock.now - started
            FileHandle.standardOutput.write(Data("elapsed_seconds \(elapsed.seconds)\n\(text)\n".utf8))
            box.code = text.isEmpty ? 2 : 0
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            box.code = 1
        }
        semaphore.signal()
    }
    semaphore.wait()
    exit(box.code)
}

KeptApp.main()

private final class TranscribeBox: @unchecked Sendable {
    var code: Int32 = 1
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
