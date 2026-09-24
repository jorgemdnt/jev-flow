import AppKit
import KeptCore
import SwiftUI

struct KeptApp: App {
    var body: some Scene {
        MenuBarExtra("Kept") {
            Text(Formatter.format("Kept"))
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

KeptApp.main()
