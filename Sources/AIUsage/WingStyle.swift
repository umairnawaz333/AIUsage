import Foundation

/// The nine looks for the small area to the right of the notch.
enum WingStyle: String, CaseIterable, Identifiable {
    case stacked, dotPair, concentric, twinRings, twinRingsNumbers, thinBars, signal, battery, alternating

    var id: String { rawValue }

    var letter: String {
        String(UnicodeScalar(UInt8(65 + Self.allCases.firstIndex(of: self)!)))
    }

    var title: String {
        switch self {
        case .stacked: "Stacked numbers"
        case .dotPair: "Two numbers"
        case .concentric: "Concentric rings"
        case .twinRings: "Twin rings"
        case .twinRingsNumbers: "Twin rings with numbers"
        case .thinBars: "Two thin bars"
        case .signal: "Signal columns"
        case .battery: "Split battery"
        case .alternating: "Alternating"
        }
    }

    var note: String {
        switch self {
        case .stacked: "5h on top, weekly below."
        case .dotPair: "Session % · weekly % on one line."
        case .concentric: "Outer ring session, inner ring weekly."
        case .twinRings: "Two rings, no text. Smallest."
        case .twinRingsNumbers: "Each ring with its %."
        case .thinBars: "Session bar over weekly bar."
        case .signal: "Two columns, like a signal meter."
        case .battery: "Top half session, bottom half weekly."
        case .alternating: "Switches between 5h and weekly."
        }
    }
}

enum SettingsKey {
    static let wingStyle = "wingStyle"
    static let showIcon = "showClaudeIcon"
}
