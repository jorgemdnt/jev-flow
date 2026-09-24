import AppKit
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

KeptApp.main()
