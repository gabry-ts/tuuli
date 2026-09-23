import SwiftUI
import TuuliCore

/// The menu bar popover: key temperatures, fans, and a quick mode switch.
struct MenuContent: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Environment(FanEngine.self) private var engine
    @Environment(HelperClient.self) private var helper
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            section("Temperatures") {
                ForEach(monitor.availableAggregates, id: \.self) { aggregate in
                    row(aggregate.title, store.settings.unit.format(monitor.value(aggregate.sensorID)))
                }
            }
            Divider()
            section("Fans") {
                if monitor.fans.isEmpty {
                    Text("No fans detected").foregroundStyle(.secondary)
                }
                ForEach(monitor.fans) { fan in
                    row(fan.name, fan.current > 0 ? "\(Int(fan.current.rounded())) rpm" : "Off")
                }
                Picker("Mode", selection: modeBinding) {
                    ForEach(FanMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .disabled(!helper.isReady)
                if !helper.isReady {
                    Text("Install the helper in Settings to control fans.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let target = engine.targetPercent {
                    Text("Holding \(Int(target.rounded()))% · \(monitor.isOnBattery ? "Battery" : "Power Adapter")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Button("Settings…", action: openSettings)
                    .keyboardShortcut(",")
                Spacer()
                Button("Quit Tuuli") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    /// Mode of whichever config is active for the current power source.
    private var modeBinding: Binding<FanMode> {
        let onBattery = store.settings.separateBatteryConfig && monitor.isOnBattery
        return store.binding(onBattery ? \.batteryConfig.mode : \.adapterConfig.mode)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
