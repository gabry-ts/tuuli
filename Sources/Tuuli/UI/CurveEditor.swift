import Charts
import PartitiUI
import SwiftUI
import TuuliCore

/// The curve as a chart whose points can be dragged, with the sensor it follows above it
/// and fine-tuning rows below.
struct CurveEditor: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.puiAccent) private var accent
    @Binding var points: [CurvePoint]
    @Binding var sensor: String
    let current: Double?
    @State private var draggingID: UUID?
    @State private var showsValues = false

    /// The temperatures the chart spans, in °C.
    private static let span: ClosedRange<Double> = 20...110

    var body: some View {
        let unit = store.settings.unit
        let ink = Ink(colorScheme)
        let sorted = points.sorted { $0.temperature < $1.temperature }
        VStack(alignment: .leading, spacing: PUI.Space.m) {
            HStack(spacing: PUI.Space.m) {
                Text("Follows")
                    .font(PUI.Font.body)
                    .foregroundStyle(ink.primary)
                SensorField(title: "Follows", selection: $sensor)
                Spacer()
                Button {
                    let last = sorted.last
                    points.append(CurvePoint(temperature: min((last?.temperature ?? 60) + 5, 110), percent: min((last?.percent ?? 50) + 10, 100)))
                } label: {
                    Label("Add Point", systemImage: "plus").labelStyle(TightLabelStyle())
                }
                .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
                Button {
                    withAnimation(PUI.Motion.spring(reduceMotion: false)) { showsValues.toggle() }
                } label: {
                    Label(showsValues ? "Hide Values" : "Values", systemImage: "list.bullet").labelStyle(TightLabelStyle())
                }
                .buttonStyle(SecondaryButtonStyle(height: PUI.Control.small))
            }

            chart(sorted: sorted, unit: unit, ink: ink)
                .frame(height: 250)

            if showsValues {
                VStack(spacing: PUI.Space.s) {
                    ForEach($points) { $point in
                        HStack(spacing: PUI.Space.l) {
                            Text("At")
                                .font(PUI.Font.body)
                                .foregroundStyle(ink.primary)
                            StepperValue(unit.format(point.temperature), value: $point.temperature, in: Self.span)
                            PUISlider(value: $point.percent, in: 0...100, step: 5)
                            ValueText("\(Int(point.percent))%", width: 44)
                            Button {
                                points.removeAll { $0.id == point.id }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(points.count <= 2 ? ink.quaternary : ink.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(points.count <= 2)
                            .help("Remove Point")
                        }
                    }
                }
                .padding(.top, PUI.Space.xs)
            }
        }
    }

    private func chart(sorted: [CurvePoint], unit: TemperatureUnit, ink: Ink) -> some View {
        // The engine holds the first point's speed below it and the last one's above it,
        // so the line runs flat to both ends of the chart.
        let ends: [(x: Double, y: Double)] = sorted.isEmpty ? [] :
            [(Self.span.lowerBound, sorted[0].percent)]
            + sorted.map { ($0.temperature, $0.percent) }
            + [(Self.span.upperBound, sorted[sorted.count - 1].percent)]
        let line = ends.enumerated().map { (index: $0.offset, x: unit.convert($0.element.x), y: $0.element.y) }
        return Chart {
            ForEach(line, id: \.index) { point in
                AreaMark(x: .value("Temperature", point.x), y: .value("Speed", point.y))
                    .foregroundStyle(.linearGradient(colors: [accent.color.opacity(0.30), accent.color.opacity(0.02)],
                                                     startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Temperature", point.x), y: .value("Speed", point.y))
                    .foregroundStyle(accent.color)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            if let current {
                RuleMark(x: .value("Now", unit.convert(current)))
                    .foregroundStyle(Heat.color(current))
                    .lineStyle(StrokeStyle(lineWidth: 1.25, dash: [3, 3]))
                    .annotation(position: .top, alignment: .center) {
                        Text(verbatim: "Now \(unit.short(current))")
                            .font(PUI.Font.badge)
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, PUI.Space.s)
                            .frame(height: 16)
                            .background(Capsule().fill(PUI.legible(Heat.color(current), colorScheme)))
                    }
            }
            ForEach(sorted) { point in
                let selected = draggingID == point.id
                PointMark(x: .value("Temperature", unit.convert(point.temperature)), y: .value("Speed", point.percent))
                    .symbol {
                        ZStack {
                            if selected {
                                Circle().fill(accent.color.opacity(0.22)).frame(width: 28, height: 28)
                            }
                            Circle().fill(Color.white)
                            Circle().stroke(accent.color, lineWidth: 2.5)
                        }
                        .frame(width: selected ? 16 : 13, height: selected ? 16 : 13)
                        .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
                    }
                    .annotation(position: .top, spacing: PUI.Space.m) {
                        if selected {
                            Text(verbatim: "\(unit.short(point.temperature)) · \(Int(point.percent))%")
                                .font(PUI.Font.label)
                                .monospacedDigit()
                                .foregroundStyle(ink.primary)
                                .padding(.horizontal, PUI.Space.m)
                                .frame(height: PUI.Control.small)
                                .puiGlass(Capsule())
                        }
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: unit.convert(Self.span.lowerBound)...unit.convert(Self.span.upperBound))
        .chartYAxis {
            AxisMarks(position: .leading, values: [0.0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(ink.hairline)
                AxisValueLabel {
                    if let percent = value.as(Double.self) {
                        Text(verbatim: "\(Int(percent))%")
                            .font(PUI.Font.caption)
                            .monospacedDigit()
                            .foregroundStyle(ink.tertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let degrees = value.as(Double.self) {
                        Text(verbatim: "\(Int(degrees))°")
                            .font(PUI.Font.caption)
                            .monospacedDigit()
                            .foregroundStyle(ink.tertiary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(.rect)
                    .gesture(dragGesture(proxy: proxy, geometry: geometry, unit: unit))
            }
        }
    }

    private func dragGesture(proxy: ChartProxy, geometry: GeometryProxy, unit: TemperatureUnit) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let plot = proxy.plotFrame else { return }
                let origin = geometry[plot].origin
                let location = CGPoint(x: value.location.x - origin.x, y: value.location.y - origin.y)
                if draggingID == nil {
                    draggingID = nearestPoint(to: location, proxy: proxy, unit: unit)
                }
                guard let id = draggingID, let index = points.firstIndex(where: { $0.id == id }),
                      let x: Double = proxy.value(atX: location.x),
                      let y: Double = proxy.value(atY: location.y) else { return }
                let celsius = unit == .celsius ? x : (x - 32) * 5 / 9
                points[index].temperature = min(max(celsius, 20), 110).rounded()
                points[index].percent = (min(max(y, 0), 100) / 5).rounded() * 5
            }
            .onEnded { _ in draggingID = nil }
    }

    private func nearestPoint(to location: CGPoint, proxy: ChartProxy, unit: TemperatureUnit) -> UUID? {
        let candidates = points.compactMap { point -> (UUID, CGFloat)? in
            guard let x = proxy.position(forX: unit.convert(point.temperature)),
                  let y = proxy.position(forY: point.percent) else { return nil }
            return (point.id, hypot(x - location.x, y - location.y))
        }
        guard let nearest = candidates.min(by: { $0.1 < $1.1 }), nearest.1 < 24 else { return nil }
        return nearest.0
    }
}
