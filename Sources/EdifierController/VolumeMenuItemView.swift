import AppKit

@MainActor
final class VolumeMenuItemView: NSView {
    var onVolumeChanged: ((Int) -> Void)?

    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 30, target: nil, action: nil)
    private let quietImage = NSImageView()
    private let loudImage = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 34))

        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        slider.isContinuous = true
        slider.controlSize = .small
        slider.setAccessibilityLabel("Volume")

        quietImage.image = NSImage(
            systemSymbolName: "speaker.fill",
            accessibilityDescription: "Low volume"
        )
        loudImage.image = NSImage(
            systemSymbolName: "speaker.wave.3.fill",
            accessibilityDescription: "High volume"
        )

        [quietImage, slider, loudImage].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            quietImage.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            quietImage.centerYAnchor.constraint(equalTo: centerYAnchor),
            quietImage.widthAnchor.constraint(equalToConstant: 16),
            quietImage.heightAnchor.constraint(equalToConstant: 16),

            slider.leadingAnchor.constraint(equalTo: quietImage.trailingAnchor, constant: 9),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),

            loudImage.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 9),
            loudImage.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            loudImage.centerYAnchor.constraint(equalTo: centerYAnchor),
            loudImage.widthAnchor.constraint(equalToConstant: 18),
            loudImage.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(value: Int, maximum: Int, isEnabled: Bool) {
        slider.maxValue = Double(max(maximum, 1))
        slider.doubleValue = Double(value)
        slider.isEnabled = isEnabled
        quietImage.contentTintColor = isEnabled ? .labelColor : .disabledControlTextColor
        loudImage.contentTintColor = isEnabled ? .labelColor : .disabledControlTextColor
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        onVolumeChanged?(sender.integerValue)
    }
}
