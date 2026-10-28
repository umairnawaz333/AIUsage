import SwiftUI

/// Layout of the physical notch on the current screen, in points.
struct NotchGeometry: Equatable {
    /// Width of the camera notch, or 0 on screens without one.
    var notchWidth: CGFloat
    /// Height of the menu bar / notch.
    var height: CGFloat

    static let expandedExtra: CGFloat = 70
    static let expandedMinWidth: CGFloat = 230
    static let expandedHeight: CGFloat = 50

    var expandedSize: CGSize {
        CGSize(width: max(notchWidth + Self.expandedExtra, Self.expandedMinWidth),
               height: height + Self.expandedHeight)
    }
}

@MainActor
final class IslandModel: ObservableObject {
    @Published var expanded = false
    @Published var geometry = NotchGeometry(notchWidth: 0, height: 32)
    /// Size of the collapsed island, reported by the view so hover hit-testing matches what is drawn.
    @Published var collapsedSize = CGSize(width: 60, height: 32)

    var onOpenSettings: () -> Void = {}
    var onQuit: () -> Void = {}
}

struct IslandView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var store: UsageStore
    @AppStorage(SettingsKey.wingStyle) private var styleRaw = WingStyle.concentric.rawValue
    @AppStorage(SettingsKey.showIcon) private var showIcon = true

    private var style: WingStyle { WingStyle(rawValue: styleRaw) ?? .concentric }
    private var geo: NotchGeometry { model.geometry }

    var body: some View {
        ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(bottomLeadingRadius: model.expanded ? 16 : 10,
                                   bottomTrailingRadius: model.expanded ? 16 : 10,
                                   style: .continuous)
                .fill(.black)
                .frame(width: model.expanded ? geo.expandedSize.width : model.collapsedSize.width,
                       height: model.expanded ? geo.expandedSize.height : geo.height)
                .shadow(color: .black.opacity(model.expanded ? 0.45 : 0), radius: 14, y: 8)

            wing
                .opacity(model.expanded ? 0 : 1)

            if model.expanded {
                ExpandedView(store: store, onOpenSettings: model.onOpenSettings, onQuit: model.onQuit)
                    .frame(width: geo.expandedSize.width - 24)
                    .padding(.top, geo.height + 2)
                    .padding(.horizontal, 12)
                    .transition(.opacity.animation(.easeOut(duration: 0.18).delay(0.08)))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: model.expanded)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contextMenu {
            Button("Settings…", action: model.onOpenSettings)
            Button("Quit AI Usage", action: model.onQuit)
        }
    }

    private var wing: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: geo.notchWidth + (geo.notchWidth > 0 ? 4 : 8))
            WingView(style: style, snapshot: store.current, showIcon: showIcon)
            Spacer().frame(width: geo.notchWidth > 0 ? 6 : 8)
        }
        .frame(height: geo.height)
        .fixedSize()
        .onGeometryChange(for: CGSize.self, of: \.size) { size in
            model.collapsedSize = size
        }
    }
}

struct ExpandedView: View {
    @ObservedObject var store: UsageStore
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    private let font = Font.system(size: 8.5, weight: .semibold).monospacedDigit()
    private let small = Font.system(size: 8.5).monospacedDigit()

    var body: some View {
        let snap = store.current
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                ClaudeMark()
                Text("Claude").font(font)
                Spacer()
                if let reset = snap?.session.resetsAt {
                    Text("resets \(UsageFormat.countdown(to: reset, from: store.now))")
                        .font(small).foregroundStyle(Palette.muted)
                }
            }
            row("5h", snap?.session.percent)
            row("W", snap?.weekly.percent)
            HStack(spacing: 6) {
                Group {
                    if let snap {
                        if let weeklyReset = snap.weekly.resetsAt {
                            Text("Weekly resets \(UsageFormat.weekdayTime(weeklyReset))")
                        } else {
                            Text("Updated \(UsageFormat.age(of: snap.savedAt, from: store.now))")
                        }
                    } else {
                        Text("No data yet. Run Claude Code once.")
                    }
                }
                .font(.system(size: 7.5))
                .foregroundStyle(Palette.muted)
                Spacer()
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill").font(.system(size: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.muted)
                .help("Settings")
            }
            .padding(.top, 1)
        }
        .foregroundStyle(.white)
    }

    private func row(_ label: String, _ percent: Int?) -> some View {
        HStack(spacing: 5) {
            Text(label).font(small).foregroundStyle(Palette.muted).frame(width: 12, alignment: .leading)
            GeometryReader { geo in
                HBar(percent: percent ?? 0, width: geo.size.width, height: 4)
                    .frame(maxHeight: .infinity)
            }
            .frame(height: 4)
            Text(percent.map { "\($0)%" } ?? "--").font(font).frame(width: 26, alignment: .trailing)
        }
    }
}
