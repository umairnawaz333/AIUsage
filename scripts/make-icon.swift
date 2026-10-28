// Draws the app icon and writes Resources/AppIcon.icns.
// Run from the repo root: swift scripts/make-icon.swift
import AppKit

let outDir = URL(fileURLWithPath: "Resources")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024

    // Tile on Apple's macOS icon grid: 824pt body inside 1024 with soft corners.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(starting: color(0x2C2C30), ending: color(0x0B0B0D))!.draw(in: tilePath, angle: -90)

    // Notch: a black tab hanging from the top edge.
    let notch = NSBezierPath()
    let nw = 360 * s, nh = 92 * s, r = 46 * s
    let nx = tile.midX - nw / 2, top = tile.maxY
    notch.move(to: NSPoint(x: nx, y: top))
    notch.line(to: NSPoint(x: nx, y: top - nh + r))
    notch.appendArc(withCenter: NSPoint(x: nx + r, y: top - nh + r), radius: r, startAngle: 180, endAngle: 270)
    notch.line(to: NSPoint(x: nx + nw - r, y: top - nh))
    notch.appendArc(withCenter: NSPoint(x: nx + nw - r, y: top - nh + r), radius: r, startAngle: 270, endAngle: 360)
    notch.line(to: NSPoint(x: nx + nw, y: top))
    notch.close()
    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSColor.black.setFill()
    notch.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Concentric rings: outer = session, inner = weekly.
    let center = NSPoint(x: tile.midX, y: tile.midY - 40 * s)
    func ring(radius: CGFloat, width: CGFloat, fraction: CGFloat, tint: NSColor) {
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = width
        color(0x3A3A3C).setStroke()
        track.stroke()
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
        arc.lineWidth = width
        arc.lineCapStyle = .round
        tint.setStroke()
        arc.stroke()
    }
    ring(radius: 250 * s, width: 58 * s, fraction: 0.68, tint: color(0x34C759))
    ring(radius: 160 * s, width: 58 * s, fraction: 0.42, tint: color(0xFF9F0A))

    // Claude spark in the middle.
    let spark = NSBezierPath()
    let sr = 62 * s
    for i in 0..<4 {
        let a = CGFloat(i) * .pi / 4
        spark.move(to: NSPoint(x: center.x - cos(a) * sr, y: center.y - sin(a) * sr))
        spark.line(to: NSPoint(x: center.x + cos(a) * sr, y: center.y + sin(a) * sr))
    }
    spark.lineWidth = 20 * s
    spark.lineCapStyle = .round
    color(0xD97757).setStroke()
    spark.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = CGFloat(base * scale)
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try drawIcon(size: px).representation(using: .png, properties: [:])!
            .write(to: iconset.appendingPathComponent(name))
    }
}
try drawIcon(size: 1024).representation(using: .png, properties: [:])!
    .write(to: outDir.appendingPathComponent("AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outDir.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
