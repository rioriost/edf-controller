import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var speakerController: SpeakerController?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let speakerController = SpeakerController()
        self.speakerController = speakerController
        menuBarController = MenuBarController(speakerController: speakerController)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

let application = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
application.run()
