import SwiftUI

/// Layout of the physical notch on the current screen, in points.
struct NotchGeometry: Equatable {
    /// Width of the camera notch, or 0 on screens without one.
    var notchWidth: CGFloat
    /// Height of the menu bar / notch.
    var height: CGFloat

    /// The box that drops down under the island on hover. Its width matches the island, but never less than this.
    static let detailSize = CGSize(width: 172, height: 38)
}

@MainActor
final class IslandModel: ObservableObject {
    @Published var expanded = false
    @Published var geometry = NotchGeometry(notchWidth: 0, height: 32)
    /// Size of the collapsed island, reported by the view so hover hit-testing matches what is drawn.
    @Published var collapsedSize = CGSize(width: 60, height: 32)

    var onOpenSettings: () -> Void = {}
    var onQuit: () -> Void = {}

    /// Full island width, so the box sits under the whole notch and wing.
    var detailWidth: CGFloat { max(collapsedSize.width, NotchGeometry.detailSize.width) }

    /// Left edge of the detail box relative to the island; only negative when the island is narrower than the box.
    var detailOffsetX: CGFloat { collapsedSize.width - detailWidth }
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
            UnevenRoundedRectangle(bottomLeadingRadius: model.expanded ? 0 : 10,
                                   bottomTrailingRadius: model.expanded ? 0 : 10,
                                   style: .continuous)
                .fill(.black)
                .frame(width: model.collapsedSize.width, height: geo.height)

            wing

            if model.expanded {
                DetailView(store: store)
                    .frame(width: model.detailWidth, height: NotchGeometry.detailSize.height)
                    .background(
                        UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous)
                            .fill(.black)
                            .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
                    )
                    .offset(x: model.detailOffsetX, y: geo.height)
                    .transition(.opacity.combined(with: .offset(y: -8)))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: model.expanded)
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

/// Two rows: 5-hour and weekly, each with a bar, the %, and when it resets.
struct DetailView: View {
    @ObservedObject var store: UsageStore

    private let font = Font.system(size: 9.5, weight: .semibold).monospacedDigit()
    private let small = Font.system(size: 9.5).monospacedDigit()

    var body: some View {
        let snap = store.current
        VStack(spacing: 4) {
            row("5h", snap?.session.percent,
                reset: snap?.session.resetsAt.map { UsageFormat.countdown(to: $0, from: store.now) })
            row("W", snap?.weekly.percent,
                reset: snap?.weekly.resetsAt.map(UsageFormat.weekdayHour))
        }
        .padding(.horizontal, 14)
        .foregroundStyle(.white)
    }

    private func row(_ label: String, _ percent: Int?, reset: String?) -> some View {
        HStack(spacing: 5) {
            Text(label).font(small).foregroundStyle(Palette.muted).frame(width: 13, alignment: .leading)
            GeometryReader { geo in
                HBar(percent: percent ?? 0, width: geo.size.width, height: 4)
                    .frame(maxHeight: .infinity)
            }
            .frame(height: 4)
            Text(percent.map { "\($0)%" } ?? "--")
                .font(font)
                .foregroundStyle(Palette.number(percent ?? 0))
                .frame(width: 30, alignment: .trailing)
            Text(reset ?? "")
                .font(small)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
                .frame(width: 46, alignment: .leading)
        }
    }
}
