import AppKit
import Observation
import SwiftUI

/// The menu bar item and its popover. Managed directly instead of through MenuBarExtra,
/// which does not reliably redraw its label, so the spinning icon and live readings
/// update on every change.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let render: () -> NSImage?

    init(content: some View, render: @escaping () -> NSImage?) {
        self.render = render
        super.init()
        let host = NSHostingController(rootView: content)
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        item.button?.target = self
        item.button?.action = #selector(toggle)
        refresh()
    }

    func closePopover() {
        popover.performClose(nil)
    }

    /// Draws the image and re-arms tracking, so any change to what it reads (settings,
    /// readings, spin angle) triggers the next draw.
    private func refresh() {
        let image = withObservationTracking {
            render()
        } onChange: { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        item.button?.image = image ?? NSImage(systemSymbolName: "fan.fill", accessibilityDescription: "Tuuli")
    }

    @objc private func toggle() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
