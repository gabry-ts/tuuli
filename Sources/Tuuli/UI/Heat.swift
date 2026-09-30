import SwiftUI
import TuuliCore

/// Tuuli's thermal scale: cool aqua, fresh green, warm amber, hot coral. It is the only
/// strong color besides the accent, so heat reads at a glance.
enum Heat {
    static func color(_ celsius: Double?) -> Color {
        guard let celsius else { return .secondary }
        switch celsius {
        case ..<50: return Color(red: 0.25, green: 0.72, blue: 0.85)
        case ..<65: return Color(red: 0.30, green: 0.75, blue: 0.55)
        case ..<80: return Color(red: 0.96, green: 0.66, blue: 0.25)
        default: return Color(red: 0.95, green: 0.38, blue: 0.36)
        }
    }

    /// Position of a temperature on the 20–100 °C scale used by meters and rings.
    static func fraction(_ celsius: Double?) -> Double {
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

extension FanStatus {
    var rpmText: String {
        current > 0 ? "\(Int(current.rounded())) rpm" : "Resting"
    }
}
