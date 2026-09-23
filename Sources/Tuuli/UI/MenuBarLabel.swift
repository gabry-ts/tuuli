import SwiftUI
import TuuliCore

/// The status item. Rendered to a template image, since MenuBarExtra labels only show a
/// single text or image and the readings are laid out side by side.
struct MenuBarLabel: View {
    let store: SettingsStore
    let monitor: Monitor

    var body: some View {
        if let image = rendered {
            Image(nsImage: image)
        } else {
            Image(systemName: "fan.fill")
        }
    }

    private var rendered: NSImage? {
        let menuBar = store.settings.menuBar
        let unit = store.settings.unit
        var readings: [String] = []
        for sensor in [menuBar.primarySensor, menuBar.secondarySensor].compactMap({ $0 }) {
            readings.append(unit.short(monitor.value(sensor)))
        }
        if menuBar.showFanSpeed, let fan = monitor.fans.map(\.current).max() {
            readings.append("\(Int(fan.rounded())) rpm")
        }
        let showIcon = menuBar.showIcon || readings.isEmpty

        let content = HStack(spacing: 4) {
            if showIcon {
                Image(systemName: "fan.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            ForEach(Array(readings.enumerated()), id: \.offset) { _, text in
                Text(text)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
            }
        }
        .foregroundStyle(.black)
        .fixedSize()

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }
}
