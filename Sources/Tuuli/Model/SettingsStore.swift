import Foundation
import Observation

/// Holds the settings and persists them to disk as JSON.
@MainActor
@Observable
final class SettingsStore {
    var settings: Settings {
        didSet { if settings != oldValue { scheduleSave() } }
    }

    private var saveTask: Task<Void, Never>?
    /// False for the in-memory store used when rendering offscreen snapshots.
    private let persistsToDisk: Bool

    static let directory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Tuuli", isDirectory: true)
    private static let fileURL = directory.appendingPathComponent("settings.json")

    init() {
        persistsToDisk = true
        settings = Self.load() ?? Settings()
    }

    init(settings: Settings) {
        persistsToDisk = false
        self.settings = settings
    }

    static var hasSavedSettings: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    private static func load() -> Settings? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Settings.self, from: data)
    }

    private func scheduleSave() {
        guard persistsToDisk else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        guard persistsToDisk else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settings) else { return }
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
