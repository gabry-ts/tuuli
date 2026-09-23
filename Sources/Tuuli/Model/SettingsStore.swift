import Foundation
import Observation
import TuuliCore

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

// MARK: Profiles

extension SettingsStore {
    @discardableResult
    func addProfile() -> UUID {
        let profile = FanProfile(name: uniqueName("New Profile"), config: FanConfig())
        settings.profiles.append(profile)
        return profile.id
    }

    @discardableResult
    func duplicateProfile(_ id: UUID) -> UUID? {
        guard let source = settings.profiles.first(where: { $0.id == id }) else { return nil }
        let copy = FanProfile(name: uniqueName("\(source.name) Copy"), config: source.config)
        settings.profiles.append(copy)
        return copy.id
    }

    func renameProfile(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let index = settings.index(of: id) else { return }
        settings.profiles[index].name = trimmed
    }

    func deleteProfile(_ id: UUID) {
        guard settings.profiles.count > 1 else { return }
        settings.profiles.removeAll { $0.id == id }
        settings.repairProfileReferences()
    }

    /// Picks a profile by hand. Choosing the profile already assigned to the current
    /// power source simply returns to automatic switching.
    func chooseProfile(_ id: UUID, onBattery: Bool) {
        settings.overrideProfileID = id == settings.automaticProfileID(onBattery: onBattery) ? nil : id
    }

    private func uniqueName(_ base: String) -> String {
        let names = Set(settings.profiles.map(\.name))
        guard names.contains(base) else { return base }
        var n = 2
        while names.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }
}
