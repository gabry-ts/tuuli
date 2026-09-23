import Charts
import SwiftUI
import TuuliCore

struct OverviewView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Environment(FanEngine.self) private var engine

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                    ForEach(monitor.availableAggregates, id: \.self) { aggregate in
                        tile(aggregate.title, store.settings.unit.format(monitor.value(aggregate.sensorID)))
                    }
                    ForEach(monitor.fans) { fan in
                        tile(fan.name, fan.current > 0 ? "\(Int(fan.current.rounded())) rpm" : "Off")
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("Window", selection: store.binding(\.historyMinutes)) {
                    Text("5 min").tag(5)
                    Text("15 min").tag(15)
                    Text("60 min").tag(60)
                }
                .pickerStyle(.segmented)
                HistoryChart(minutes: store.settings.historyMinutes)
            } header: {
                Text("History")
            } footer: {
                Text(statusLine)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var statusLine: String {
        let source = monitor.isOnBattery ? "Battery" : "Power Adapter"
        let mode = store.settings.activeMode
        if let target = engine.targetPercent {
            return "\(source) · \(mode.name) · holding \(Int(target.rounded()))%"
        }
        return "\(source) · \(mode.name) · system controls the fans"
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
    }
}

struct HistoryChart: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    let minutes: Int

    private var samples: [HistorySample] {
        let start = Date().addingTimeInterval(-Double(minutes) * 60)
        return monitor.history.filter { $0.date >= start }
    }

    private var series: [Aggregate] {
        [.cpuHottest, .cpuAverage, .gpuHottest, .ssdHottest, .batteryHottest]
            .filter { monitor.availableAggregates.contains($0) }
    }

    var body: some View {
        let unit = store.settings.unit
        VStack(alignment: .leading, spacing: 16) {
            Chart {
                ForEach(series, id: \.self) { aggregate in
                    ForEach(samples) { sample in
                        if let value = sample.values[aggregate.sensorID] {
                            LineMark(
                                x: .value("Time", sample.date),
                                y: .value("Temperature", unit.convert(value))
                            )
                            .foregroundStyle(by: .value("Sensor", aggregate.title))
                        }
                    }
                }
            }
            .chartYAxisLabel(unit.symbol)
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 200)

            if !monitor.fans.isEmpty {
                Chart {
                    ForEach(monitor.fans) { fan in
                        ForEach(samples) { sample in
                            if let value = sample.values["fan\(fan.id)"] {
                                LineMark(
                                    x: .value("Time", sample.date),
                                    y: .value("RPM", value)
                                )
                                .foregroundStyle(by: .value("Fan", fan.name))
                            }
                        }
                    }
                }
                .chartYAxisLabel("rpm")
                .frame(height: 120)
            }
        }
        .padding(.vertical, 4)
    }
}
