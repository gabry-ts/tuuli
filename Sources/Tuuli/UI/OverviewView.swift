import Charts
import PartitiUI
import SwiftUI
import TuuliCore

struct OverviewView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Environment(FanEngine.self) private var engine
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let unit = store.settings.unit
        let ink = Ink(colorScheme)
        let main = monitor.value(Aggregate.cpuHottest.sensorID) ?? monitor.value(Aggregate.hottest.sensorID)
        let windows: [(value: Int, title: LocalizedStringKey)] = [(5, "5 min"), (15, "15 min"), (60, "60 min")]
        TuuliPane(.overview, subtitle: statusLine) {
            SettingsGroup("Now") {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: PUI.Space.s) {
                        Badge(Heat.mood(main), color: main == nil ? nil : Heat.color(main))
                        BigNumber(unit.short(main), font: .system(size: 56, weight: .light, design: .rounded).monospacedDigit())
                        Text("CPU, hottest core")
                            .font(PUI.Font.callout)
                            .foregroundStyle(ink.secondary)
                    }
                    Spacer()
                    Image(systemName: "fan.fill")
                        .font(.system(size: 64))
                        .foregroundStyle((monitor.fans.map(\.current).max() ?? 0) > 0
                                         ? AppAccent.tuuli.legible(colorScheme) : ink.tertiary)
                }
                .padding(PUI.Space.xl)
            }

            let rings = monitor.availableAggregates.filter { $0 != .cpuHottest && $0 != .hottest }
            if !rings.isEmpty {
                SettingsGroup("Temperatures") {
                    HStack {
                        ForEach(rings, id: \.self) { aggregate in
                            let value = monitor.value(aggregate.sensorID)
                            VStack(spacing: PUI.Space.m) {
                                GaugeRing(Heat.fraction(value), color: Heat.color(value), lineWidth: 7, size: 84) {
                                    Text(verbatim: unit.short(value))
                                        .font(PUI.Font.stat)
                                        .foregroundStyle(ink.primary)
                                }
                                Text(aggregate.title)
                                    .font(PUI.Font.label)
                                    .foregroundStyle(ink.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(PUI.Space.xl)
                }
            }

            if !monitor.fans.isEmpty {
                SettingsGroup("Fans") {
                    ForEach(monitor.fans) { fan in
                        HStack(spacing: PUI.Space.l) {
                            RowSymbol("fan.fill", color: fan.current > 0 ? AppAccent.tuuli.legible(colorScheme) : nil)
                            Text(fan.name)
                                .font(PUI.Font.body)
                                .foregroundStyle(ink.primary)
                                .frame(width: 72, alignment: .leading)
                            Meter(fan.current > 0 ? max(fan.percent, 3) / 100 : 0, height: 6)
                            Text(verbatim: fan.rpmText)
                                .font(PUI.Font.body)
                                .monospacedDigit()
                                .foregroundStyle(ink.secondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.horizontal, PUI.Space.l)
                        .frame(minHeight: 38)
                    }
                }
            }

            SettingsGroup("History") {
                VStack(alignment: .leading, spacing: PUI.Space.l) {
                    HStack {
                        Spacer()
                        SegmentedPill(windows, selection: store.binding(\.historyMinutes), height: PUI.Control.regular)
                    }
                    HistoryChart(minutes: store.settings.historyMinutes)
                }
                .padding(PUI.Space.l)
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
        AppAccent.tuuli.color,
        Color(red: 0.62, green: 0.52, blue: 0.95),
        Color(red: 0.30, green: 0.78, blue: 0.70),
        Color(red: 0.96, green: 0.70, blue: 0.30),
    ]

    /// The chosen window, always shown in full even while history is still short.
    private var window: ClosedRange<Date> {
        let now = monitor.history.last?.date ?? Date()
        return now.addingTimeInterval(-Double(minutes) * 60)...now
    }

    /// At most ~180 points per series: more is invisible at this size and costly to draw.
    private var samples: [HistorySample] {
        let start = Date().addingTimeInterval(-Double(minutes) * 60)
        return monitor.history.filter { $0.date >= start }.thinned(to: 180)
    }

    private var series: [Aggregate] {
        [.cpuHottest, .cpuAverage, .gpuHottest, .ssdHottest, .batteryHottest]
            .filter { monitor.availableAggregates.contains($0) }
    }

    var body: some View {
        let unit = store.settings.unit
        if samples.count < 3 {
            VStack(spacing: PUI.Space.s) {
                Image(systemName: "wind")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
                Text("Catching the breeze")
                    .font(PUI.Font.headline)
                Text("History fills in as Tuuli keeps watching.")
                    .font(PUI.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
        } else {
            chart(unit: unit)
        }
    }

    private func chart(unit: TemperatureUnit) -> some View {
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
            .chartXScale(domain: window)
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
                    range: monitor.fans.indices.map { $0 == 0 ? AppAccent.tuuli.color : Color(red: 0.45, green: 0.80, blue: 0.95) }
                )
                .chartXScale(domain: window)
                .chartYAxisLabel("rpm")
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 110)
            }
        }
    }
}
