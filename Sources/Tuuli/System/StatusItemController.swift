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
    private let render: () -> StatusContent

    init(content: some View, render: @escaping () -> StatusContent) {
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
        let content = withObservationTracking {
            render()
        } onChange: { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        guard let button = item.button else { return }
        button.image = content.icon
        button.imagePosition = switch (content.icon != nil, content.title.isEmpty) {
        case (true, true): .imageOnly
        case (true, false): content.iconLeading ? .imageLeading : .imageTrailing
        case (false, _): .noImage
        }
        // Setting the title only when it changes keeps spin frames to an image swap.
        if button.title != content.title {
            button.attributedTitle = NSAttributedString(string: content.title, attributes: [.font: StatusImage.font])
        }
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
