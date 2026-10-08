import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/TopMovies.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sourceImageURL = root.appendingPathComponent("docs/branding/app_icon_transparent.png")
let masterImage: NSImage? = FileManager.default.fileExists(atPath: sourceImageURL.path) ? NSImage(contentsOf: sourceImageURL) : nil

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale
        let targetSize = NSSize(width: px, height: px)
        let image = NSImage(size: targetSize)
        image.lockFocus()

        if let master = masterImage {
            NSGraphicsContext.current?.imageInterpolation = .high
            master.draw(in: NSRect(origin: .zero, size: targetSize),
                        from: NSRect(origin: .zero, size: master.size),
                        operation: .copy,
                        fraction: 1.0)
        } else {
            let width = CGFloat(px)
            NSColor(calibratedRed: 0.075, green: 0.085, blue: 0.10, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: width * 0.07, y: width * 0.07, width: width * 0.86, height: width * 0.86), xRadius: width * 0.19, yRadius: width * 0.19).fill()
            let film = NSRect(x: width * 0.24, y: width * 0.22, width: width * 0.52, height: width * 0.56)
            let color = NSColor(calibratedRed: 0.97, green: 0.72, blue: 0.32, alpha: 1)
            color.setStroke(); color.setFill()
            let outline = NSBezierPath(roundedRect: film, xRadius: width * 0.035, yRadius: width * 0.035)
            outline.lineWidth = max(1, width * 0.025); outline.stroke()
            for i in 0..<4 {
                for x in [0.27, 0.685] { NSBezierPath(roundedRect: NSRect(x: width * x, y: width * (0.255 + Double(i) * 0.13), width: width * 0.045, height: width * 0.06), xRadius: width * 0.008, yRadius: width * 0.008).fill() }
            }
            let play = NSBezierPath(); play.move(to: NSPoint(x: width * 0.43, y: width * 0.37)); play.line(to: NSPoint(x: width * 0.43, y: width * 0.63)); play.line(to: NSPoint(x: width * 0.63, y: width * 0.50)); play.close(); play.fill()
        }

        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let file = iconset.appendingPathComponent("icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: file)
    }
}

