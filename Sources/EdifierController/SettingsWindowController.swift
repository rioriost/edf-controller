import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(speakerController: SpeakerController) {
        let view = SettingsView(speakerController: speakerController)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Edifier Controller Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 440, height: 240))
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct SettingsView: View {
    @ObservedObject var speakerController: SpeakerController

    private var selection: Binding<String> {
        Binding(
            get: {
                speakerController.selectedSpeakerID?.uuidString ?? "automatic"
            },
            set: { value in
                if value == "automatic" {
                    speakerController.selectAutomatic()
                } else if let id = UUID(uuidString: value) {
                    speakerController.selectSpeaker(id: id)
                }
            }
        )
    }

    var body: some View {
        Form {
            Picker("Speaker", selection: selection) {
                Text("Automatic (Recommended)").tag("automatic")
                ForEach(speakerController.discoveredSpeakers) { speaker in
                    Text(speaker.displayName).tag(speaker.id.uuidString)
                }
            }

            LabeledContent("Status") {
                Text(speakerController.connectionState.description)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Spacer()
                Button("Scan Again") {
                    speakerController.rescan()
                }
            }

            Text("Automatic selects the strongest compatible S880DB MKII. Select a specific speaker when more than one compatible device is nearby. A specific selection never falls back to another speaker.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 440, height: 240)
    }
}
