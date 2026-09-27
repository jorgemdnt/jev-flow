import AppKit
import AVFoundation
import ApplicationServices
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

// Read-only diagnostic. Run the installed executable so its bundle resources and
// privacy attribution are the ones under test; this does not request permission.
if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--verify-doctor" {
    let mic = AVCaptureDevice.authorizationStatus(for: .audio)
    let micStatus: String = switch mic {
    case .authorized: "authorized"
    case .denied: "denied"
    case .restricted: "restricted"
    case .notDetermined: "not-determined"
    @unknown default: "unknown"
    }
    let model = ParakeetEngine.bundleDirectory
    let required = ["parakeet_vocab.json", "Preprocessor.mlmodelc", "Encoder.mlmodelc", "Decoder.mlmodelc", "JointDecisionv3.mlmodelc"]
    let modelsPresent = model.map { directory in
        required.allSatisfy { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) }
    } ?? false
    FileHandle.standardOutput.write(Data("accessibility \(AXIsProcessTrusted() ? "authorized" : "missing")\nmicrophone \(micStatus)\nopencode_key \(OpenCodeKey.load() == nil ? "missing" : "present")\nmodels \(modelsPresent ? "present" : "missing")\n".utf8))
    exit(0)
}

if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--ui-snapshot" {
    let directory = CommandLine.arguments[2]
    let window = UISnapshot.save(in: directory)
    let cards = LiveCardSnapshot.save(in: directory)
    FileHandle.standardOutput.write(Data("window_snapshots \(window) card_snapshots \(cards)\n".utf8))
    exit(window && cards ? 0 : 1)
}

if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--transcribe" {
    let path = CommandLine.arguments[2]
    let box = TranscribeBox()
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
        box.complete = true
    }
    while !box.complete {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }
    exit(box.code)
}

if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--render-edit-card" {
    let path = CommandLine.arguments[2]
    let dark = CommandLine.arguments.contains("dark")
    let long = CommandLine.arguments.contains("long")
    exit(EditCardSnapshot.save(to: path, dark: dark, long: long) ? 0 : 1)
}

if CommandLine.arguments.count >= 2, ["--probe-edit", "--probe-edit-bad-key"].contains(CommandLine.arguments[1]) {
    let box = TranscribeBox()
    let badKey = CommandLine.arguments[1] == "--probe-edit-bad-key"
    Task { @MainActor in
        var proposed = ""
        let result = await OpenCodeClient.edit(
            text: "Ship it tomorrow.", instruction: "Change tomorrow to Friday.",
            key: badKey ? "invalid-probe-key" : OpenCodeKey.load(),
            matchesTarget: { true }, paste: { proposed = $0; return true }
        )
        let notice = result.notice
        FileHandle.standardOutput.write(Data("edit_probe_outcome \(result)\nedit_probe_proposed \(proposed)\nedit_probe_notice \(notice.map { "\($0.title): \($0.body)" } ?? "none")\n".utf8))
        box.code = badKey ? (result == .unauthorized ? 0 : 1) : (result == .applied && proposed == "Ship it Friday." ? 0 : 1)
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
