import Foundation
import Observation

/// Turns the menu bar fan while the fans run, faster as they speed up. Ticks only while
/// spinning, so an idle Mac costs nothing.
@MainActor
@Observable
final class IconSpinner {
    private(set) var angle: Double = 0
    private var step: Double = 0
    private var timer: Timer?

    /// - Parameter percent: fan speed across its range, or nil when the fans are stopped.
    func update(percent: Double?) {
        guard let percent else {
            timer?.invalidate()
            timer = nil
            angle = 0
            return
        }
        // The glyph has four blades, so a quarter turn loops seamlessly. Steps stay under
        // 45° per frame, beyond which the blades would seem to turn backwards.
        step = 8 + 32 * min(max(percent, 0), 100) / 100
        guard timer == nil else { return }
        // Every frame makes AppKit re-snapshot the status item on each display, so the
        // rate stays low; 10 fps still reads as smooth motion.
        let timer = Timer(timeInterval: 1.0 / 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.angle = (self.angle + self.step).truncatingRemainder(dividingBy: 90)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
