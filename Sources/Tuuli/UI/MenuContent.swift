import Charts
import PartitiUI
import SwiftUI
import TuuliCore

/// The menu bar popover. Each section can be turned on or off under Menu Bar settings.
struct MenuContent: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Monitor.self) private var monitor
    @Environment(FanEngine.self) private var engine
    @Environment(HelperClient.self) private var helper
    @Environment(Updater.self) private var updater
    let openSettings: () -> Void
    /// Applies fan changes right away instead of waiting for the next sample.
    let applyNow: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let popover = store.settings.popover
        PopoverScaffold {
            PopoverHeader(icon: Image(nsImage: NSApp.applicationIconImage), name: "Tuuli") {
                HeaderStatus(monitor.isOnBattery ? "Battery" : "Power Adapter",
                             symbol: monitor.isOnBattery ? "battery.75percent" : "bolt.fill")
            }
        } content: {
            ForEach(popover.sections.filter(\.isEnabled), id: \.section) { entry in
                sectionView(entry.section, popover: popover)
            }
        } footer: {
            PopoverFooter(
                onSettings: openSettings,
                onCheckForUpdates: { updater.checkForUpdates() },
                onBuyMeACoffee: { NSWorkspace.shared.open(Links.buyMeACoffee) })
        }
        .puiAccent(.tuuli)
    }

    @ViewBuilder
    private func sectionView(_ section: PopoverSection, popover: PopoverSettings) -> some View {
        let unit = store.settings.unit
        let ink = Ink(colorScheme)
        switch section {
        case .temperatures:
            if !popover.temperatureSensors.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: PUI.Space.xs) {
                        SectionHeader("Temperatures")
                        ForEach(Array(popover.temperatureSensors.enumerated()), id: \.offset) { _, sensor in
                            HStack(spacing: PUI.Space.m) {
                                Circle()
                                    .fill(Heat.color(monitor.value(sensor)))
                                    .frame(width: 7, height: 7)
                                    .frame(width: 16)
                                Text(monitor.name(of: sensor))
                                    .font(PUI.Font.body)
                                    .foregroundStyle(ink.primary)
                                    .lineLimit(1)
                                Spacer(minLength: PUI.Space.m)
                                Text(verbatim: unit.short(monitor.value(sensor)))
                                    .font(PUI.Font.body)
                                    .monospacedDigit()
                                    .foregroundStyle(ink.secondary)
                            }
                            .frame(height: PUI.Control.small)
                        }
                    }
                }
            }
        case .chart:
            Card {
                hero(sensor: popover.chartSensor, minutes: popover.chartMinutes)
            }
        case .fans:
            Card {
                VStack(alignment: .leading, spacing: PUI.Space.xs) {
                    SectionHeader("Fan speeds") {
                        if !monitor.fans.isEmpty {
                            Text(monitor.fans.count == 1 ? "1 fan" : "\(monitor.fans.count) fans")
                        }
                    }
                    if monitor.fans.isEmpty {
                        Text("No fans on this Mac")
                            .font(PUI.Font.body)
                            .foregroundStyle(ink.secondary)
                            .frame(height: PUI.Control.small)
                    }
                    ForEach(monitor.fans) { fan in
                        HStack(spacing: PUI.Space.m) {
                            RowSymbol("fan.fill", color: fan.current > 0 ? AppAccent.tuuli.legible(colorScheme) : nil)
                            Text(fan.name)
                                .font(PUI.Font.body)
                                .foregroundStyle(ink.primary)
                                .lineLimit(1)
                                .frame(width: 72, alignment: .leading)
                            Meter(fan.current > 0 ? max(fan.percent, 3) / 100 : 0, height: 4)
                            Text(verbatim: fan.rpmText)
                                .font(PUI.Font.body)
                                .monospacedDigit()
                                .foregroundStyle(ink.secondary)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .frame(height: PUI.Control.small)
                    }
                }
            }
        case .modePicker:
            Card {
                modeSection
            }
        }
    }

    private func hero(sensor: String, minutes: Int) -> some View {
        let value = monitor.value(sensor)
        return VStack(alignment: .leading, spacing: PUI.Space.m) {
            SectionHeader(monitor.name(of: sensor)) { Text("last \(minutes) min") }
            HStack(alignment: .bottom, spacing: PUI.Space.l) {
                VStack(alignment: .leading, spacing: PUI.Space.xxs) {
                    BigNumber(store.settings.unit.short(value))
                    Badge(Heat.mood(value), color: value == nil ? nil : Heat.color(value))
                }
                sparkline(sensor: sensor, minutes: minutes)
                    .padding(.bottom, PUI.Space.xxs)
            }
        }
    }

    // MARK: Mode

    private var activeMode: Mode { store.settings.activeMode }

    private var modeSection: some View {
        let ink = Ink(colorScheme)
        return VStack(alignment: .leading, spacing: PUI.Space.m) {
            SectionHeader("Mode") {
                if helper.isReady { Text(holdingText).monospacedDigit() }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: PUI.Space.s), GridItem(.flexible(), spacing: PUI.Space.s)],
                      spacing: PUI.Space.s) {
                ForEach(store.settings.modes) { mode in
                    Chip(mode.name, symbol: mode.kind.icon, active: mode.id == store.settings.activeModeID) {
                        store.settings.activeModeID = mode.id
                        applyNow()
                    }
                }
            }
            .disabled(!helper.isReady)
            .opacity(helper.isReady ? 1 : 0.5)

            if activeMode.kind == .manual {
                HStack(spacing: PUI.Space.m) {
                    RowSymbol("wind")
                    PUISlider(value: manualPercent, in: 0...100)
                        // The fans follow once the drag ends, not on every step of it.
                        .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { _ in applyNow() })
                    Text(verbatim: "\(Int(activeMode.adapter.manualPercent))%")
                        .font(PUI.Font.body)
                        .monospacedDigit()
                        .foregroundStyle(ink.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .disabled(!helper.isReady)
            }

            if !helper.isReady {
                HStack {
                    Text("Fan control needs the helper.")
                        .font(PUI.Font.caption)
                        .foregroundStyle(ink.secondary)
                    Spacer()
                    Button("Set Up…", action: openSettings)
                        .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                }
            }
        }
    }

    private var holdingText: String {
        engine.targetPercent.map { "Fans held at \(Int($0.rounded()))%" } ?? "macOS is in charge of the fans"
    }

    private var manualPercent: Binding<Double> {
        Binding(
            get: { activeMode.adapter.manualPercent },
            set: { value in
                if let index = store.settings.index(of: activeMode.id) {
                    store.settings.modes[index].adapter.manualPercent = (value / 5).rounded() * 5
                }
            }
        )
    }

    // MARK: Pieces

    private func sparkline(sensor: String, minutes: Int) -> some View {
        let start = Date().addingTimeInterval(-Double(minutes) * 60)
        let unit = store.settings.unit
        let points = monitor.history.filter { $0.date >= start }.thinned(to: 90).compactMap { sample in
            sample.values[sensor].map { (sample.date, unit.convert($0)) }
        }
        let low = (points.map(\.1).min() ?? 0) - 2
        let high = (points.map(\.1).max() ?? 1) + 2
        let color = AppAccent.tuuli.color
        return Chart {
            ForEach(points, id: \.0) { point in
                AreaMark(x: .value("Time", point.0), yStart: .value("Low", low), yEnd: .value("Temperature", point.1))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.linearGradient(colors: [color.opacity(0.28), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Time", point.0), y: .value("Temperature", point.1))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
            }
            if let last = points.last {
                PointMark(x: .value("Time", last.0), y: .value("Temperature", last.1))
                    .symbol {
                        Circle()
                            .fill(color)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .frame(width: 6, height: 6)
                    }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: low...max(high, low + 1))
        .frame(height: 48)
    }
}
