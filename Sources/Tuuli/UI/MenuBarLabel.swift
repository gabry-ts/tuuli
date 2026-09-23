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
                .renderingMode(.template)
        } else {
            Image(systemName: "fan.fill")
        }
    }

    private var fanSpeed: String {
        guard let rpm = monitor.fans.map(\.current).max() else { return "– rpm" }
        return "\(Int(rpm.rounded())) rpm"
    }

    private var rendered: NSImage? {
        let unit = store.settings.unit
        let items: [StatusElement] = store.settings.menuBar.items.isEmpty ? [.icon] : store.settings.menuBar.items

        let content = HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                switch item {
                case .icon:
                    Image(systemName: "fan.fill")
                        .font(.system(size: 13, weight: .medium))
                case .temperature(let sensor):
                    Text(unit.short(monitor.value(sensor)))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                case .fanSpeed:
                    Text(fanSpeed)
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                }
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
