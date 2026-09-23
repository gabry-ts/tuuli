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

// MARK: Modes

extension SettingsStore {
    @discardableResult
    func addMode() -> UUID {
        let mode = Mode(name: uniqueName("New Mode"), kind: .curve)
        settings.modes.append(mode)
        return mode.id
    }

    /// Copies any mode, built-in or not, into a new custom mode.
    @discardableResult
    func duplicateMode(_ id: UUID) -> UUID? {
        guard var copy = settings.modes.first(where: { $0.id == id }) else { return nil }
        copy.id = UUID()
        copy.name = uniqueName("\(copy.name) Copy")
        copy.isBuiltIn = false
        settings.modes.append(copy)
        return copy.id
    }

    func renameMode(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let index = settings.index(of: id) else { return }
        settings.modes[index].name = trimmed
    }

    func deleteMode(_ id: UUID) {
        guard settings.modes.first(where: { $0.id == id })?.isBuiltIn == false else { return }
        settings.modes.removeAll { $0.id == id }
        if settings.activeModeID == id {
            settings.activeModeID = settings.modes[0].id
        }
    }

    private func uniqueName(_ base: String) -> String {
        let names = Set(settings.modes.map(\.name))
        guard names.contains(base) else { return base }
        var n = 2
        while names.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }
}
