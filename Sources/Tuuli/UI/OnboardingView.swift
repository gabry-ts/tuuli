import SwiftUI
import TuuliCore

/// First launch: welcome, fan control helper, and a starting mode.
struct OnboardingView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(HelperClient.self) private var helper
    @State private var step: Int
    let finish: () -> Void

    init(step: Int = 0, finish: @escaping () -> Void) {
        _step = State(initialValue: step)
        self.finish = finish
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch step {
                case 0: welcome
                case 1: fanControl
                default: chooseMode
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(step)

            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(index == step ? AnyShapeStyle(Theme.sky) : AnyShapeStyle(.primary.opacity(0.15)))
                            .frame(width: index == step ? 18 : 6, height: 6)
                    }
                }
                Spacer()
                if step > 0 {
                    Button("Back") { go(step - 1) }
                        .buttonStyle(.borderless)
                }
                Button(step == 2 ? "Start Using Tuuli" : "Continue") {
                    step == 2 ? finish() : go(step + 1)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.sky)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 560, height: 460)
        .background(AirBackground())
        .animation(.smooth, value: step)
    }

    private func go(_ next: Int) {
        withAnimation(.smooth) { step = next }
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .shadow(color: Theme.sky.opacity(0.35), radius: 20, y: 8)
            Text("Welcome to Tuuli")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("A gentle breeze for your Mac. Keep an eye on temperatures from the menu bar, and let the fans spin up when you want them to.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)
        }
    }

    private var fanControl: some View {
        VStack(spacing: 16) {
            Image(systemName: helper.isReady ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(helper.isReady ? AnyShapeStyle(Theme.heat(55)) : AnyShapeStyle(Theme.sky.gradient))
                .contentTransition(.symbolEffect(.replace))
            Text("Fan control")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("Setting fan speeds needs a small helper that runs in the background. It only ever sets fan speeds, and hands them back to macOS whenever Tuuli quits or your Mac sleeps.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            if helper.isReady {
                Label("Helper installed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.heat(55))
            } else {
                Button("Install Helper…") { helper.install() }
                    .controlSize(.large)
                Text("You can skip this and just watch temperatures. It's also in Settings › General.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if let error = helper.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var chooseMode: some View {
        VStack(spacing: 16) {
            Image(systemName: "wind")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.sky.gradient)
            Text("Pick a starting mode")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("You can switch anytime from the menu bar, and create your own modes in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)
            VStack(spacing: 8) {
                ForEach(store.settings.modes.filter(\.isBuiltIn)) { mode in
                    Button {
                        store.settings.activeModeID = mode.id
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.kind.icon)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(mode.name).fontWeight(.medium)
                                Text(mode.kind.tagline)
                                    .font(.caption)
                                    .opacity(0.75)
                            }
                            Spacer()
                            if mode.id == store.settings.activeModeID {
                                Image(systemName: "checkmark")
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(mode.id == store.settings.activeModeID ? .white : .primary)
                        .background(
                            mode.id == store.settings.activeModeID
                                ? AnyShapeStyle(Theme.sky.gradient) : AnyShapeStyle(.primary.opacity(0.05)),
                            in: .rect(cornerRadius: 10)
                        )
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 380)
        }
    }
}

extension FanMode {
    var tagline: String {
        switch self {
        case .system: "Let macOS decide"
        case .boost: "Full speed once things get warm"
        case .curve: "Speed follows the temperature"
        case .manual: "A fixed speed you choose"
        }
    }
}
