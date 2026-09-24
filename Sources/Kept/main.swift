import AppKit
import KeptCore
import SwiftUI

@MainActor
struct KeptApp: App {
    @State private var session = Session()

    var body: some Scene {
        MenuBarExtra("Kept", systemImage: session.recording ? "mic.fill" : "mic") {
            Text(session.status)
            if session.takes.isEmpty {
                Text("No takes yet")
            }
            ForEach(session.takes) { take in
                Divider()
                Text(take.rawTranscript.isEmpty ? "(empty transcript)" : take.rawTranscript)
                Text(durationLabel(take.durationSeconds))
                Button("Dismiss") {
                    session.dismiss(take.id)
                }
            }
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}

private func durationLabel(_ seconds: Double) -> String {
    String(format: "%.1f s", seconds)
}

KeptApp.main()
