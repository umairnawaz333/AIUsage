import SwiftUI

enum Palette {
    static let claude = Color(red: 0.851, green: 0.467, blue: 0.341)   // #D97757
    static let ok = Color(red: 0.204, green: 0.780, blue: 0.349)       // #34C759
    static let warn = Color(red: 1.0, green: 0.624, blue: 0.039)       // #FF9F0A
    static let bad = Color(red: 1.0, green: 0.271, blue: 0.227)        // #FF453A
    static let track = Color(white: 0.23)
    static let muted = Color(white: 0.56)

    static func level(_ percent: Int) -> Color {
        percent >= 90 ? bad : percent >= 70 ? warn : ok
    }

    /// Numbers stay white until they get close to the limit.
    static func number(_ percent: Int) -> Color {
        percent >= 70 ? level(percent) : .white
    }
}

/// The small orange spark used for Claude.
struct ClaudeMark: View {
    var size: CGFloat = 7.7

    var body: some View {
        SparkShape()
            .stroke(Palette.claude, style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round))
            .frame(width: size, height: size)
    }

    private struct SparkShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let r = min(rect.width, rect.height) / 2 * 0.85
            for angle in stride(from: 0.0, to: 180.0, by: 45.0) {
                let a = angle * .pi / 180
                let dx = cos(a) * r, dy = sin(a) * r
                path.move(to: CGPoint(x: c.x - dx, y: c.y - dy))
                path.addLine(to: CGPoint(x: c.x + dx, y: c.y + dy))
            }
            return path
        }
    }
}

struct RingView: View {
    var percent: Int
    var diameter: CGFloat
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Palette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(Palette.level(percent), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
    }
}

struct HBar: View {
    var percent: Int
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Palette.track)
            Capsule().fill(Palette.level(percent)).frame(width: width * CGFloat(percent) / 100)
        }
        .frame(width: width, height: height)
    }
}

private struct VBar: View {
    var percent: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 1).fill(Palette.track)
            Rectangle().fill(Palette.level(percent)).frame(height: 11 * CGFloat(percent) / 100)
        }
        .frame(width: 3, height: 11)
        .clipShape(RoundedRectangle(cornerRadius: 1))
    }
}

private struct BatteryView: View {
    var session: Int
    var weekly: Int

    var body: some View {
        HStack(spacing: 0.5) {
            VStack(spacing: 1.5) {
                half(session)
                half(weekly)
            }
            .padding(1.5)
            .frame(width: 18, height: 10)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(white: 0.39), lineWidth: 1.2))
            RoundedRectangle(cornerRadius: 0.75).fill(Color(white: 0.39)).frame(width: 1.5, height: 4)
        }
    }

    private func half(_ percent: Int) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 1)
                .fill(Palette.level(percent))
                .frame(width: geo.size.width * CGFloat(percent) / 100)
        }
    }
}

/// What sits to the right of the notch while it is collapsed.
struct WingView: View {
    var style: WingStyle
    var snapshot: UsageSnapshot?
    var showIcon: Bool

    private var s: Int { snapshot?.session.percent ?? 0 }
    private var w: Int { snapshot?.weekly.percent ?? 0 }

    private let numberFont = Font.system(size: 9.5, weight: .semibold).monospacedDigit()
    private let tinyFont = Font.system(size: 7.2, weight: .semibold).monospacedDigit()

    var body: some View {
        HStack(spacing: 4) {
            if showIcon { ClaudeMark() }
            if snapshot == nil {
                Text("--").font(numberFont).foregroundStyle(Palette.muted)
            } else {
                content
            }
        }
        .fixedSize()
    }

    @ViewBuilder private var content: some View {
        switch style {
        case .stacked:
            VStack(alignment: .trailing, spacing: 0) {
                labeled("5h", s, font: tinyFont)
                labeled("W", w, font: tinyFont)
            }
        case .dotPair:
            HStack(spacing: 3) {
                pct(s)
                Text("·").font(.system(size: 7.7)).foregroundStyle(Palette.muted)
                pct(w).opacity(0.85)
            }
        case .concentric:
            HStack(spacing: 3) {
                pct(s)
                ZStack {
                    RingView(percent: s, diameter: 9.6, lineWidth: 1.45)
                    RingView(percent: w, diameter: 5, lineWidth: 1.45)
                }
                .frame(width: 12, height: 12)
            }
        case .twinRings:
            HStack(spacing: 3) {
                RingView(percent: s, diameter: 7, lineWidth: 1.5).frame(width: 10, height: 10)
                RingView(percent: w, diameter: 7, lineWidth: 1.5).frame(width: 10, height: 10)
            }
        case .twinRingsNumbers:
            HStack(spacing: 2) {
                RingView(percent: s, diameter: 6.3, lineWidth: 1.5).frame(width: 9, height: 9)
                pct(s)
                Spacer().frame(width: 3)
                RingView(percent: w, diameter: 6.3, lineWidth: 1.5).frame(width: 9, height: 9)
                pct(w)
            }
        case .thinBars:
            HStack(spacing: 4) {
                VStack(spacing: 2) {
                    HBar(percent: s, width: 18, height: 2)
                    HBar(percent: w, width: 18, height: 2)
                }
                pct(s)
            }
        case .signal:
            HStack(spacing: 3) {
                pct(s).padding(.trailing, 2)
                VBar(percent: s)
                VBar(percent: w)
            }
        case .battery:
            BatteryView(session: s, weekly: w)
        case .alternating:
            TimelineView(.periodic(from: .now, by: 2.5)) { context in
                let showWeekly = Int(context.date.timeIntervalSinceReferenceDate / 2.5) % 2 == 1
                labeled(showWeekly ? "W" : "5h", showWeekly ? w : s, font: numberFont, labelSize: 7.7)
                    .animation(.easeInOut(duration: 0.25), value: showWeekly)
            }
        }
    }

    private func pct(_ value: Int) -> some View {
        Text("\(value)%").font(numberFont).foregroundStyle(Palette.number(value))
    }

    private func labeled(_ label: String, _ value: Int, font: Font, labelSize: CGFloat? = nil) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(labelSize.map { .system(size: $0, weight: .medium) } ?? font)
                .foregroundStyle(Palette.muted)
            Text("\(value)%").font(font).foregroundStyle(Palette.number(value))
        }
    }
}
