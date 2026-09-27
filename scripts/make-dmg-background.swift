#!/usr/bin/env swift
// Renders the DMG background in the app's sky blues, at 1x and 2x.
// Run with `swift scripts/make-dmg-background.swift`; writes into Resources/dmg/.

import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let outDir = root.appendingPathComponent("Resources/dmg")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func render(scale: CGFloat, name: String) {
    let size = CGSize(width: 600 * scale, height: 400 * scale)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("could not create a bitmap for \(name)")
    }
    NSGraphicsContext.current = context

    // The same pale sky as the app's window background.
    let top = NSColor(calibratedRed: 0.92, green: 0.96, blue: 1.0, alpha: 1)
    let bottom = NSColor(calibratedRed: 0.98, green: 0.99, blue: 1.0, alpha: 1)
    NSGradient(starting: top, ending: bottom)?.draw(in: CGRect(origin: .zero, size: size), angle: -90)

    func glow(_ color: NSColor, center: CGPoint, radius: CGFloat) {
        NSGradient(starting: color, ending: color.withAlphaComponent(0))?
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius)
    }
    glow(NSColor(calibratedRed: 0.36, green: 0.64, blue: 1.0, alpha: 0.18),
         center: CGPoint(x: size.width * 0.1, y: size.height * 0.9), radius: size.width * 0.45)
    glow(NSColor(calibratedRed: 0.55, green: 0.85, blue: 0.95, alpha: 0.22),
         center: CGPoint(x: size.width * 0.9, y: size.height * 0.1), radius: size.width * 0.4)

    // A soft arrow between the app and the Applications link, as make-dmg.sh places them.
    let y = size.height * 0.525
    let start = CGPoint(x: size.width * 0.42, y: y)
    let end = CGPoint(x: size.width * 0.58, y: y)
    let arrow = NSBezierPath()
    arrow.move(to: start)
    arrow.line(to: end)
    arrow.move(to: CGPoint(x: end.x - 10 * scale, y: end.y - 8 * scale))
    arrow.line(to: end)
    arrow.line(to: CGPoint(x: end.x - 10 * scale, y: end.y + 8 * scale))
    arrow.lineWidth = 3 * scale
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSColor(calibratedRed: 0.36, green: 0.64, blue: 1.0, alpha: 0.55).setStroke()
    arrow.stroke()

    context.flushGraphics()
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("could not encode \(name)")
    }
    let url = outDir.appendingPathComponent(name)
    try? png.write(to: url)
    print("wrote \(url.path)")
}

render(scale: 1, name: "background.png")
render(scale: 2, name: "background@2x.png")
