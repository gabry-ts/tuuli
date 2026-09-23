import Foundation
import UserNotifications

/// Posts a notification when an alert rule's sensor crosses its threshold, at most once
/// per cooldown period per rule.
@MainActor
final class Notifier {
    private var lastFired: [UUID: Date] = [:]
    private var didRequestAuthorization = false

    func check(settings: Settings, monitor: Monitor) {
        let now = Date()
        for rule in settings.alerts where rule.isEnabled {
            guard let value = monitor.value(rule.sensor), value >= rule.threshold else { continue }
            if let last = lastFired[rule.id], now.timeIntervalSince(last) < settings.alertCooldownMinutes * 60 {
                continue
            }
            lastFired[rule.id] = now
            post(
                title: "\(monitor.name(of: rule.sensor)) is at \(settings.unit.format(value))",
                body: "Above your alert threshold of \(settings.unit.format(rule.threshold)).",
                sound: settings.alertSound
            )
        }
    }

    func requestAuthorization() {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func post(title: String, body: String, sound: Bool) {
        requestAuthorization()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound { content.sound = .default }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
