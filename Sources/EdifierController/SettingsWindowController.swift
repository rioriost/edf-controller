import AppKit
import EdifierCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(speakerController: SpeakerController) {
        let view = SettingsView(speakerController: speakerController)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Edf Controller Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 500))
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

    private let bandLabels = ["62 Hz", "250 Hz", "1 kHz", "4 kHz", "8 kHz", "16 kHz"]

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

    private func gainBinding(for index: Int) -> Binding<Double> {
        Binding(
            get: {
                guard speakerController.customEQGains.indices.contains(index) else { return 0 }
                return speakerController.customEQGains[index]
            },
            set: { gain in
                speakerController.setCustomEQGain(bandIndex: index, gain: gain)
            }
        )
    }

    private func gainLabel(_ gain: Double) -> String {
        if gain > 0 { return String(format: "+%.1f dB", gain) }
        return String(format: "%.1f dB", gain)
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

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Customized EQ")
                    .font(.headline)

                HStack(alignment: .center, spacing: 12) {
                    VStack {
                        Text("+3 dB")
                            .fixedSize()
                        Spacer()
                        Text("0 dB")
                            .fixedSize()
                        Spacer()
                        Text("−3 dB")
                            .fixedSize()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 180)

                    ForEach(bandLabels.indices, id: \.self) { index in
                        VStack(spacing: 6) {
                            Text(gainLabel(speakerController.customEQGains[index]))
                                .font(.caption.monospacedDigit())
                                .frame(width: 58)

                            VerticalGainSlider(
                                value: gainBinding(for: index),
                                isEnabled: speakerController.connectionState.isReady
                            )
                            .frame(width: 30, height: 150)

                            Text(bandLabels[index])
                                .font(.caption)
                                .frame(width: 58)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 520, height: 500)
        .onAppear {
            speakerController.refreshCustomEQ()
        }
    }
}

private struct VerticalGainSlider: NSViewRepresentable {
    @Binding var value: Double
    let isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(
            value: value,
            minValue: CustomEQCodec.minimumGain,
            maxValue: CustomEQCodec.maximumGain,
            target: context.coordinator,
            action: #selector(Coordinator.valueChanged(_:))
        )
        slider.isVertical = true
        slider.isContinuous = true
        slider.numberOfTickMarks = 13
        slider.allowsTickMarkValuesOnly = true
        slider.controlSize = .small
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.parent = self
        if slider.doubleValue != value {
            slider.doubleValue = value
        }
        slider.isEnabled = isEnabled
    }

    final class Coordinator: NSObject {
        var parent: VerticalGainSlider

        init(parent: VerticalGainSlider) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: NSSlider) {
            parent.value = sender.doubleValue
        }
    }
}
