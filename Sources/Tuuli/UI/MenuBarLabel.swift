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

/// What the status item shows: readings as real menu bar text, so they match the clock
/// and other system items exactly, and the fan icon as a (possibly rotated) image.
struct StatusContent {
    var icon: NSImage?
    /// Whether the icon sits before the text; the text is kept together.
    var iconLeading = true
    var title = ""
}

@MainActor
enum StatusImage {
    private enum Part {
        case icon
        case text(String)
    }

    /// The system menu bar font, with fixed-width digits so readings don't jitter.
    static let font: NSFont = {
        let base = NSFont.menuBarFont(ofSize: 0)
        let descriptor = base.fontDescriptor.addingAttributes([
            .featureSettings: [[
                NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
            ]],
        ])
        return NSFont(descriptor: descriptor, size: base.pointSize) ?? base
    }()

    private static let glyph = NSImage(systemSymbolName: "fan.fill", accessibilityDescription: "Tuuli")?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: font.pointSize, weight: .regular))

    private static let separator = "  "

    private static func parts(store: SettingsStore, monitor: Monitor) -> [Part] {
        let unit = store.settings.unit
        let fastest = monitor.fans.map(\.current).max()
        return store.settings.menuBar.displayedItems.map { item in
            switch item {
            case .icon: .icon
            case .temperature(let sensor): .text(unit.short(monitor.value(sensor)))
            case .fanSpeed: .text(fastest.map { "\(Int($0.rounded())) rpm" } ?? "– rpm")
            }
        }
    }

    /// Reads every observable input up front, so observation tracking around this call
    /// sees them all.
    static func content(store: SettingsStore, monitor: Monitor, angle: Double) -> StatusContent {
        let parts = parts(store: store, monitor: monitor)
        let texts = parts.compactMap { part -> String? in
            if case .text(let text) = part { return text }
            return nil
        }
        let iconIndex = parts.firstIndex { if case .icon = $0 { true } else { false } }
        return StatusContent(
            icon: iconIndex == nil ? nil : rotatedGlyph(angle),
            iconLeading: iconIndex == 0,
            title: texts.joined(separator: separator)
        )
    }

    /// The fan glyph turned by `angle`, in a square canvas so rotation never clips.
    static func rotatedGlyph(_ angle: Double) -> NSImage? {
        guard let glyph else { return nil }
        let side = ceil(max(glyph.size.width, glyph.size.height))
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let transform = NSAffineTransform()
            transform.translateX(by: side / 2, yBy: side / 2)
            transform.rotate(byDegrees: -angle)
            transform.concat()
            glyph.draw(in: NSRect(x: -glyph.size.width / 2, y: -glyph.size.height / 2,
                                  width: glyph.size.width, height: glyph.size.height))
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The whole status item as one template image, for the preview in settings.
    static func render(store: SettingsStore, monitor: Monitor, angle: Double) -> NSImage? {
        let content = content(store: store, monitor: monitor, angle: angle)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let titleSize = content.title.isEmpty ? .zero : (content.title as NSString).size(withAttributes: attributes)
        let iconSide = content.icon?.size.width ?? 0
        let gap: CGFloat = content.icon != nil && !content.title.isEmpty ? 4 : 0
        let height = max(titleSize.height, iconSide)
        let size = NSSize(width: ceil(iconSide + gap + titleSize.width), height: ceil(height))
        let image = NSImage(size: size, flipped: false) { _ in
            let textX = content.iconLeading ? iconSide + gap : 0
            let iconX = content.iconLeading ? 0 : titleSize.width + gap
            content.icon?.draw(in: NSRect(x: iconX, y: (height - iconSide) / 2, width: iconSide, height: iconSide))
            (content.title as NSString).draw(at: NSPoint(x: textX, y: (height - titleSize.height) / 2), withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }
}
