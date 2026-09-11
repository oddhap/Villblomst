import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawFlower(size s: CGFloat) {
    let inset = s * 0.055
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let rounded = NSBezierPath(roundedRect: rect, xRadius: s * 0.225, yRadius: s * 0.225)
    NSGraphicsContext.saveGraphicsState()
    rounded.addClip()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.62, green: 0.84, blue: 0.58, alpha: 1),
        NSColor(calibratedRed: 0.30, green: 0.60, blue: 0.36, alpha: 1)
    ])?.draw(in: rounded, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let center = CGPoint(x: s / 2, y: s * 0.575)
    let petalR = s * 0.165
    let ringR = s * 0.205
    NSColor.white.withAlphaComponent(0.96).setFill()
    for i in 0..<5 {
        let angle = CGFloat(i) / 5 * 2 * .pi - .pi / 2
        let px = center.x + cos(angle) * ringR
        let py = center.y + sin(angle) * ringR
        NSBezierPath(ovalIn: CGRect(x: px - petalR, y: py - petalR,
                                    width: petalR * 2, height: petalR * 2)).fill()
    }

    let coreR = s * 0.095
    NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.28, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - coreR, y: center.y - coreR,
                                width: coreR * 2, height: coreR * 2)).fill()

    let stem = NSBezierPath()
    stem.lineWidth = max(1, s * 0.035)
    stem.lineCapStyle = .round
    stem.move(to: CGPoint(x: center.x, y: center.y - petalR * 0.4))
    stem.line(to: CGPoint(x: center.x, y: s * 0.20))
    NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.26, alpha: 1).setStroke()
    stem.stroke()

    NSColor(calibratedRed: 0.24, green: 0.52, blue: 0.30, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x + s * 0.01, y: s * 0.22,
                                width: s * 0.17, height: s * 0.09)).fill()
}

func render(_ size: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    drawFlower(size: CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

let specs: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
]

for (size, name) in specs {
    guard let data = render(size) else {
        FileHandle.standardError.write("Kunne ikke tegne \(name)\n".data(using: .utf8)!)
        exit(1)
    }
    let path = (outDir as NSString).appendingPathComponent(name)
    try data.write(to: URL(fileURLWithPath: path))
}
print("Skrev ikoner til \(outDir)")
