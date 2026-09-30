import PartitiUI
import SwiftUI
import TuuliCore

/// First launch: welcome, fan control helper, and a starting mode.
struct OnboardingView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(HelperClient.self) private var helper
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Int
    let finish: () -> Void

    init(step: Int = 0, finish: @escaping () -> Void) {
        _step = State(initialValue: step)
        self.finish = finish
    }

    private var ink: Ink { Ink(colorScheme) }
    private var accent: Color { AppAccent.tuuli.color }

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
                HStack(spacing: PUI.Space.s) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(index == step ? accent : ink.strongFill)
                            .frame(width: index == step ? 18 : 6, height: 6)
                    }
                }
                Spacer()
                if step > 0 {
                    Button("Back") { go(step - 1) }
                        .buttonStyle(SecondaryButtonStyle())
                }
                Button(step == 2 ? "Start Using Tuuli" : "Continue") {
                    step == 2 ? finish() : go(step + 1)
                }
                .buttonStyle(PrimaryButtonStyle(height: PUI.Control.regular, fullWidth: false))
                .keyboardShortcut(.defaultAction)
            }
            .padding(PUI.Space.xl + 4)
        }
        .frame(width: 560, height: 460)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .animation(PUI.Motion.spring(reduceMotion: reduceMotion), value: step)
        .puiAccent(.tuuli)
    }

    private func go(_ next: Int) {
        withAnimation(PUI.Motion.spring(reduceMotion: reduceMotion)) { step = next }
    }

    private var welcome: some View {
        VStack(spacing: PUI.Space.xl) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            Text("Welcome to Tuuli")
                .font(PUI.Font.title)
                .foregroundStyle(ink.primary)
            Text("A gentle breeze for your Mac. Keep an eye on temperatures from the menu bar, and let the fans spin up when you want them to.")
                .font(PUI.Font.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ink.secondary)
                .frame(maxWidth: 400)
        }
    }

    private var fanControl: some View {
        VStack(spacing: PUI.Space.xl) {
            Image(systemName: helper.isReady ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(helper.isReady ? ink.green : AppAccent.tuuli.legible(colorScheme))
                .contentTransition(.symbolEffect(.replace))
            Text("Fan control")
                .font(PUI.Font.title)
                .foregroundStyle(ink.primary)
            Text("Setting fan speeds needs a small helper that runs in the background. It only ever sets fan speeds, and hands them back to macOS whenever Tuuli quits or your Mac sleeps.")
                .font(PUI.Font.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ink.secondary)
                .frame(maxWidth: 420)
            if helper.isReady {
                Label("Helper installed", systemImage: "checkmark.circle.fill")
                    .labelStyle(TightLabelStyle(spacing: PUI.Space.s))
                    .font(PUI.Font.headline)
                    .foregroundStyle(ink.green)
            } else {
                Button("Install Helper…") { helper.install() }
                    .buttonStyle(SecondaryButtonStyle(height: PUI.Control.large))
                Text("You can skip this and just watch temperatures. It's also in Settings › General.")
                    .font(PUI.Font.caption)
                    .foregroundStyle(ink.tertiary)
            }
            if let error = helper.lastError {
                Text(error)
                    .font(PUI.Font.caption)
                    .foregroundStyle(ink.red)
            }
        }
    }

    private var chooseMode: some View {
        VStack(spacing: PUI.Space.xl) {
            Image(systemName: "wind")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppAccent.tuuli.legible(colorScheme))
            Text("Pick a starting mode")
                .font(PUI.Font.title)
                .foregroundStyle(ink.primary)
            Text("You can switch anytime from the menu bar, and create your own modes in Settings.")
                .font(PUI.Font.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(ink.secondary)
                .frame(maxWidth: 400)
            VStack(spacing: PUI.Space.m) {
                ForEach(store.settings.modes.filter(\.isBuiltIn)) { mode in
                    let active = mode.id == store.settings.activeModeID
                    Button {
                        store.settings.activeModeID = mode.id
                    } label: {
                        Row(Text(verbatim: mode.name), subtitle: Text(mode.kind.tagline)) {
                            RowSymbol(mode.kind.icon, color: active ? AppAccent.tuuli.legible(colorScheme) : nil)
                        } trailing: {
                            CheckMark(active)
                        }
                        .padding(.horizontal, PUI.Space.l)
                        .padding(.vertical, PUI.Space.xs)
                        .puiSurface(radius: PUI.Radius.group, tint: active ? accent : nil, elevated: false)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
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
