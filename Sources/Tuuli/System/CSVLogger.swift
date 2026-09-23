import Foundation
import TuuliCore

/// Appends a row per interval to `Tuuli-<date>.csv` in the chosen folder, one file per day.
@MainActor
final class CSVLogger {
    private var lastWrite: Date?

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func log(settings: LoggingSettings, monitor: Monitor) {
        guard settings.isEnabled else { return }
        let now = Date()
        if let lastWrite, now.timeIntervalSince(lastWrite) < settings.interval - 0.25 { return }
        lastWrite = now

        let folder = URL(fileURLWithPath: settings.folderPath, isDirectory: true)
        let file = folder.appendingPathComponent("Tuuli-\(Self.dayFormatter.string(from: now)).csv")
        let aggregates = Aggregate.allCases
        let sensors = monitor.sensors

        var lines = ""
        if !FileManager.default.fileExists(atPath: file.path) {
            let header = ["timestamp"]
                + aggregates.map(\.title)
                + monitor.fans.map { "\($0.name) RPM" }
                + sensors.map { "\($0.name) (\($0.id))" }
            lines += header.map(escape).joined(separator: ",") + "\n"
        }
        let row = [ISO8601DateFormatter().string(from: now)]
            + aggregates.map { format(monitor.value($0.sensorID)) }
            + monitor.fans.map { String(Int($0.current.rounded())) }
            + sensors.map { format(monitor.value($0.id)) }
        lines += row.joined(separator: ",") + "\n"

        // Logging is best effort: an unwritable folder must not disturb monitoring.
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(lines.utf8))
        } else {
            try? Data(lines.utf8).write(to: file)
        }
    }

    private func format(_ value: Double?) -> String {
        value.map { String(format: "%.2f", $0) } ?? ""
    }

    private func escape(_ field: String) -> String {
        field.contains(",") || field.contains("\"")
            ? "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            : field
    }
}
