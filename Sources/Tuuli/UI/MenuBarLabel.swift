import SwiftUI
import TuuliCore

/// The status item as a view, for the live preview in settings.
struct MenuBarLabel: View {
    let store: SettingsStore
    let monitor: Monitor
    var spinner: IconSpinner?

    var body: some View {
        if let image = StatusImage.render(store: store, monitor: monitor, angle: spinner?.angle ?? 0) {
            Image(nsImage: image)
                .renderingMode(.template)
        } else {
            Image(systemName: "fan.fill")
        }
    }

}

/// Draws the status item's readings side by side into one template image. Plain AppKit
/// drawing, since it runs up to 20 times a second while the icon spins.
@MainActor
enum StatusImage {
    private enum Part {
        case icon
        case text(String)
    }

    private static let height: CGFloat = 18
    private static let spacing: CGFloat = 5
    private static let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
        .foregroundColor: NSColor.black,
    ]
    private static let glyph = NSImage(systemSymbolName: "fan.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))

    /// Reads every observable input up front, so observation tracking around this call
    /// sees them all.
    static func render(store: SettingsStore, monitor: Monitor, angle: Double) -> NSImage? {
        let unit = store.settings.unit
        let fastest = monitor.fans.map(\.current).max()
        let parts: [Part] = store.settings.menuBar.displayedItems.map { item in
            switch item {
            case .icon: .icon
            case .temperature(let sensor): .text(unit.short(monitor.value(sensor)))
            case .fanSpeed: .text(fastest.map { "\(Int($0.rounded())) rpm" } ?? "– rpm")
            }
        }
        guard let glyph else { return nil }

        let widths = parts.map { part -> CGFloat in
            switch part {
            case .icon: max(glyph.size.width, glyph.size.height)
            case .text(let text): ceil((text as NSString).size(withAttributes: attributes).width)
            }
        }
        let width = widths.reduce(0, +) + spacing * CGFloat(max(parts.count - 1, 0))

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            var x: CGFloat = 0
            for (part, partWidth) in zip(parts, widths) {
                switch part {
                case .icon:
                    NSGraphicsContext.saveGraphicsState()
                    let transform = NSAffineTransform()
                    transform.translateX(by: x + partWidth / 2, yBy: height / 2)
                    transform.rotate(byDegrees: -angle)
                    transform.concat()
                    let size = glyph.size
                    glyph.draw(in: NSRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
                    NSGraphicsContext.restoreGraphicsState()
                case .text(let text):
                    let size = (text as NSString).size(withAttributes: attributes)
                    (text as NSString).draw(at: NSPoint(x: x, y: (height - size.height) / 2), withAttributes: attributes)
                }
                x += partWidth + spacing
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
