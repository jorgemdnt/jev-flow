import AppKit
import KeptCore
import SwiftUI

@MainActor
struct KeptApp: App {
    @State private var session = Session()

    var body: some Scene {
        MenuBarExtra("Kept", systemImage: session.recording ? "mic.fill" : "mic") {
            Text(session.status)
            if !session.canInsert, session.status != Session.insertNeedsAccessibility {
                Text(Session.insertNeedsAccessibility)
            }
            Divider()
            Text("Last raw")
            Text(session.lastRawTranscript.isEmpty ? "No takes yet" : session.lastRawTranscript)
            Text("Last inserted")
            Text(session.lastInsertedText.isEmpty ? "Nothing inserted yet" : session.lastInsertedText)
            ForEach(session.takes) { take in
                Divider()
                Text(take.rawTranscript.isEmpty ? "(empty transcript)" : take.rawTranscript)
                Text(durationLabel(take.durationSeconds))
                if session.refusesAutoInsert(take), take.insertedText == nil {
                    Button("Insert raw") {
                        session.insertRaw(take.id)
                    }
                } else if let inserted = take.insertedText {
                    Text(inserted)
                } else {
                    if !session.keptText(take).isEmpty {
                        Text(session.keptText(take))
                    }
                    Button("Insert") {
                        session.insertKept(take.id)
                    }
                }
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
