import SwiftUI
import TuuliCore

/// Tuuli's look: airy sky gradients, frosted cards, and a soft thermal scale that is the
/// only strong color in the app, so heat reads at a glance.
enum Theme {
    static let sky = Color(red: 0.36, green: 0.64, blue: 1.0)
    static let cardRadius: CGFloat = 16

    /// Soft thermal scale: cool aqua, fresh green, warm amber, hot coral.
    static func heat(_ celsius: Double?) -> Color {
        guard let celsius else { return .secondary }
        switch celsius {
        case ..<50: return Color(red: 0.25, green: 0.72, blue: 0.85)
        case ..<65: return Color(red: 0.30, green: 0.75, blue: 0.55)
        case ..<80: return Color(red: 0.96, green: 0.66, blue: 0.25)
        default: return Color(red: 0.95, green: 0.38, blue: 0.36)
        }
    }

    static let heatGradient = Gradient(colors: [heat(40), heat(55), heat(70), heat(90)])

    /// Position of a temperature on the 20–100 °C scale used by bars and rings.
    static func heatFraction(_ celsius: Double?) -> Double {
        guard let celsius else { return 0 }
        return min(max((celsius - 20) / 80, 0), 1)
    }

    /// A one-word feel for a temperature, for headlines.
    static func mood(_ celsius: Double?) -> String {
        guard let celsius else { return "Waiting for sensors" }
        switch celsius {
        case ..<50: return "Cool"
        case ..<65: return "Calm"
        case ..<80: return "Warm"
        default: return "Hot"
        }
    }
}

// MARK: - Backgrounds and cards

/// Blurs whatever is behind the window.
struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// The window backdrop: the desktop blurred through the window, tinted with a pale sky
/// and two soft glows. "Reduce transparency" turns the blur solid automatically.
struct AirBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SettingsStore.self) private var store

    var body: some View {
        let dark = colorScheme == .dark
        let solidity = 1 - store.settings.transparency
        ZStack {
            BehindWindowBlur()
                .opacity(0.35 + 0.65 * solidity)
            LinearGradient(
                colors: dark
                    ? [Color(red: 0.07, green: 0.10, blue: 0.16), Color(red: 0.05, green: 0.07, blue: 0.11)]
                    : [Color(red: 0.92, green: 0.96, blue: 1.0), Color(red: 0.98, green: 0.99, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.85 * solidity)
            // Radial gradients rather than blurred circles: same soft glow, but no blur
            // pass to recompute each time the page redraws.
            GeometryReader { proxy in
                glow(Theme.sky.opacity(dark ? 0.24 : 0.22), radius: proxy.size.width * 0.5)
                    .position(x: proxy.size.width * 0.15, y: proxy.size.height * 0.1)
                glow(Color(red: 0.55, green: 0.85, blue: 0.95).opacity(dark ? 0.14 : 0.24), radius: proxy.size.width * 0.4)
                    .position(x: proxy.size.width * 0.9, y: proxy.size.height * 0.95)
            }
        }
        .ignoresSafeArea()
    }

    private func glow(_ color: Color, radius: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
    }
}

/// A frosted-looking card with a hairline highlight. A translucent fill rather than a
/// material: over the smooth backdrop it looks the same, without a blur pass per frame.
struct Card<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.55),
                in: .rect(cornerRadius: Theme.cardRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}

/// Scrollable page with the air backdrop, a large title and cards stacked below.
struct AirPage<Content: View>: View {
    let title: String
    var subtitle: String?
    /// Off when the page sits inside a view that already draws the backdrop.
    var drawsBackground = true
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                    if let subtitle {
                        Text(subtitle)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)
                content
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background { if drawsBackground { AirBackground() } }
    }
}

struct CardTitle: View {
    let title: String
    var systemImage: String?

    var body: some View {
        Label {
            Text(title)
        } icon: {
            if let systemImage { Image(systemName: systemImage) }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

// MARK: - Readouts

/// A temperature with fixed-width digits.
struct TemperatureText: View {
    let celsius: Double?
    let unit: TemperatureUnit
    var compact = false

    var body: some View {
        Text(verbatim: compact ? unit.short(celsius) : unit.format(celsius))
            .monospacedDigit()
    }
}

/// Thin ring gauge filled along the heat scale, with the reading in the middle.
struct HeatRing: View {
    let title: String
    let celsius: Double?
    let unit: TemperatureUnit
    var size: CGFloat = 92

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.08), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: Theme.heatFraction(celsius))
                    .stroke(Theme.heat(celsius).gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                TemperatureText(celsius: celsius, unit: unit, compact: true)
                    .font(.system(size: size * 0.24, weight: .semibold, design: .rounded))
            }
            .frame(width: size, height: size)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Capsule filled along the heat scale.
struct HeatBar: View {
    let celsius: Double?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule()
                    .fill(Theme.heat(celsius).gradient)
                    .frame(width: max(proxy.size.width * Theme.heatFraction(celsius), 4))
            }
        }
        .frame(height: 5)
    }
}

/// Fan glyph, tinted while the fan runs. Deliberately still: animating it kept the
/// whole window recompositing and cost a quarter of a core.
struct FanGlyph: View {
    let rpm: Double
    var size: CGFloat = 18

    var body: some View {
        Image(systemName: "fan.fill")
            .font(.system(size: size))
            .foregroundStyle(rpm > 0 ? AnyShapeStyle(Theme.sky.gradient) : AnyShapeStyle(.secondary))
    }
}

/// Fan speed as a soft bar across the fan's range.
struct FanBar: View {
    let fan: FanStatus

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule()
                    .fill(Theme.sky.gradient)
                    .frame(width: fan.current > 0 ? max(proxy.size.width * max(fan.percent, 3) / 100, 4) : 0)
            }
        }
        .frame(height: 5)
    }
}

/// A selectable pill for a mode, used in the popover and onboarding.
struct ModeChip: View {
    let mode: Mode
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mode.kind.icon)
                    .font(.caption)
                Text(mode.name)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isActive ? .white : .primary)
            .background(
                isActive ? AnyShapeStyle(Theme.sky.gradient) : AnyShapeStyle(.primary.opacity(0.06)),
                in: .rect(cornerRadius: 10)
            )
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isActive)
    }
}
