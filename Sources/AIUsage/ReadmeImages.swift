import AppKit
import SwiftUI

/// Draws the README images from the real views, with fixed sample numbers.
@MainActor
enum ReadmeImages {
    private static let now = Date(timeIntervalSince1970: 1793197487)
    private static let sample = UsageSnapshot(
        savedAt: now,
        session: .init(percent: 28, resetsAt: Date(timeIntervalSince1970: 1793202600)),
        weekly: .init(percent: 41, resetsAt: Date(timeIntervalSince1970: 1793286000))
    )

    private static let notchWidth: CGFloat = 185
    private static let menuBarHeight: CGFloat = 32
    private static let sceneWidth: CGFloat = 760

    struct RenderError: Error, CustomStringConvertible {
        var description: String
    }

    static func render(to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = UsageStore(previewSnapshot: sample, now: now)
        let wingWidth = try image(WingView(style: .concentric, snapshot: sample, showIcon: true)).size.width

        for expanded in [false, true] {
            let model = IslandModel()
            model.geometry = NotchGeometry(notchWidth: notchWidth, height: menuBarHeight)
            model.collapsedSize = CGSize(width: notchWidth + 4 + wingWidth + 6, height: menuBarHeight)
            model.expanded = expanded
            let scene = MenuBarScene(model: model, store: store, width: sceneWidth,
                                     height: expanded ? 104 : 58, notchWidth: notchWidth)
            try save(scene, as: expanded ? "notch-hover.png" : "notch-collapsed.png", in: dir)
        }

        try save(StylesGrid(snapshot: sample), as: "styles.png", in: dir)
    }

    private static func image(_ view: some View) throws -> NSImage {
        var result: NSImage?
        NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
            renderer.scale = 2
            result = renderer.nsImage
        }
        guard let result else { throw RenderError(description: "couldn't render image") }
        return result
    }

    private static func save(_ view: some View, as name: String, in dir: URL) throws {
        let img = try image(view)
        guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
        else { throw RenderError(description: "couldn't encode \(name)") }
        try png.write(to: dir.appendingPathComponent(name))
        print("Wrote \(dir.appendingPathComponent(name).path)")
    }
}

/// A slice of a desktop: wallpaper, menu bar, and the island over the notch.
private struct MenuBarScene: View {
    var model: IslandModel
    var store: UsageStore
    var width: CGFloat
    var height: CGFloat
    var notchWidth: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.11, green: 0.17, blue: 0.39),
                                    Color(red: 0.42, green: 0.19, blue: 0.58),
                                    Color(red: 0.97, green: 0.47, blue: 0.42)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            HStack(spacing: 18) {
                Image(systemName: "apple.logo")
                Text("Finder").fontWeight(.bold)
                Text("File")
                Text("Edit")
                Text("View")
                Spacer()
                Text("Wed 7:24 PM")
            }
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(.black.opacity(0.18))

            IslandView(model: model, store: store, styleOverride: .concentric)
                .padding(.leading, (width - notchWidth) / 2)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// All nine wing styles, as shown in Settings.
private struct StylesGrid: View {
    var snapshot: UsageSnapshot

    var body: some View {
        let rows = stride(from: 0, to: WingStyle.allCases.count, by: 3).map {
            Array(WingStyle.allCases[$0..<min($0 + 3, WingStyle.allCases.count)])
        }
        VStack(spacing: 10) {
            ForEach(rows, id: \.first) { row in
                HStack(spacing: 10) {
                    ForEach(row) { style in
                        StyleCard(style: style, snapshot: snapshot, showIcon: true, selected: style == .concentric)
                            .frame(width: 210)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.07, green: 0.07, blue: 0.08)))
    }
}
