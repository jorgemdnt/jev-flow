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
        if let front = NSWorkspace.shared.frontmostApplication {
            FocusedField.enableTree(pid: front.processIdentifier)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            FocusedField.enableTree(pid: app.processIdentifier)
        }
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

if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--render-edit-card" {
    let path = CommandLine.arguments[2]
    let dark = CommandLine.arguments.contains("dark")
    let long = CommandLine.arguments.contains("long")
    exit(EditCardSnapshot.save(to: path, dark: dark, long: long) ? 0 : 1)
}

if CommandLine.arguments.count >= 2, CommandLine.arguments[1] == "--probe-edit" {
    let box = TranscribeBox()
    Task { @MainActor in
        let result = await OpenCodeClient.edit(text: "Ship it tomorrow.", instruction: "Change tomorrow to Friday.")
        FileHandle.standardOutput.write(Data("edit_probe_response_chars \(result?.count ?? 0)\nedit_probe_matches_expected \(result == "Ship it Friday.")\n".utf8))
        box.code = result == "Ship it Friday." ? 0 : 1
        box.complete = true
    }
    while !box.complete {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }
    exit(box.code)
}

KeptApp.main()

private final class TranscribeBox: @unchecked Sendable {
    var code: Int32 = 1
    var complete = false
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
