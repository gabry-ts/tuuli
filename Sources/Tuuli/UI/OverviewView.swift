import Charts
import SwiftUI
import TuuliCore

struct OverviewView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Environment(FanEngine.self) private var engine

    var body: some View {
        let unit = store.settings.unit
        let main = monitor.value(Aggregate.cpuHottest.sensorID) ?? monitor.value(Aggregate.hottest.sensorID)
        AirPage(title: "Overview", subtitle: statusLine) {
            Card(padding: 24) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Theme.mood(main).uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(1.5)
                            .foregroundStyle(Theme.heat(main))
                        TemperatureText(celsius: main, unit: unit, compact: true)
                            .font(.system(size: 64, weight: .light, design: .rounded))
                        Text("CPU, hottest core")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    SpinningFan(rpm: monitor.fans.map(\.current).max() ?? 0, size: 72)
                        .opacity(0.9)
                }
            }

            let rings = monitor.availableAggregates.filter { $0 != .cpuHottest && $0 != .hottest }
            if !rings.isEmpty {
                Card(padding: 20) {
                    HStack {
                        ForEach(rings, id: \.self) { aggregate in
                            HeatRing(title: aggregate.title, celsius: monitor.value(aggregate.sensorID), unit: unit)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            if !monitor.fans.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        CardTitle(title: "Fans", systemImage: "wind")
                        ForEach(monitor.fans) { fan in
                            HStack(spacing: 12) {
                                SpinningFan(rpm: fan.current, size: 20)
                                Text(fan.name)
                                    .frame(width: 50, alignment: .leading)
                                FanBar(fan: fan)
                                Text(verbatim: fan.rpmText)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .trailing)
                            }
                        }
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        CardTitle(title: "History", systemImage: "chart.xyaxis.line")
                        Spacer()
                        Picker("Window", selection: store.binding(\.historyMinutes)) {
                            Text("5 min").tag(5)
                            Text("15 min").tag(15)
                            Text("60 min").tag(60)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    HistoryChart(minutes: store.settings.historyMinutes)
                }
            }
        }
    }

    private var statusLine: String {
        let source = monitor.isOnBattery ? "On battery" : "On power adapter"
        let mode = store.settings.activeMode
        if let target = engine.targetPercent {
            return "\(source) · \(mode.name) · fans held at \(Int(target.rounded()))%"
        }
        return "\(source) · \(mode.name) · macOS is in charge of the fans"
    }
}

struct HistoryChart: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    let minutes: Int

    /// Soft, airy series colors.
    static let palette: [Color] = [
        Color(red: 0.95, green: 0.45, blue: 0.42),
        Color(red: 0.36, green: 0.64, blue: 1.0),
        Color(red: 0.62, green: 0.52, blue: 0.95),
        Color(red: 0.30, green: 0.78, blue: 0.70),
        Color(red: 0.96, green: 0.70, blue: 0.30),
    ]

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
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .foregroundStyle(by: .value("Sensor", aggregate.title))
                        }
                    }
                }
            }
            .chartForegroundStyleScale(domain: series.map(\.title), range: Self.palette.prefix(series.count).map { $0 })
            .chartYAxisLabel(unit.symbol)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 200)

            if !monitor.fans.isEmpty {
                Chart {
                    ForEach(monitor.fans) { fan in
                        ForEach(samples) { sample in
                            if let value = sample.values["fan\(fan.id)"] {
                                AreaMark(
                                    x: .value("Time", sample.date),
                                    y: .value("RPM", value),
                                    stacking: .unstacked
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(by: .value("Fan", fan.name))
                                .opacity(0.35)
                            }
                        }
                    }
                }
                .chartForegroundStyleScale(
                    domain: monitor.fans.map(\.name),
                    range: monitor.fans.indices.map { $0 == 0 ? Theme.sky : Color(red: 0.45, green: 0.80, blue: 0.95) }
                )
                .chartYAxisLabel("rpm")
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 110)
            }
        }
    }
}
