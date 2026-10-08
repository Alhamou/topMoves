import CoreGraphics
import ImageIO
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/TopMovies.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sourceURL = root.appendingPathComponent("TopMovies/Resources/AppLogo.png")
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let master = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    print("Error: Could not load master image from \(sourceURL.path)")
    exit(1)
}

let colorSpace = CGColorSpaceCreateDeviceRGB()

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale
        guard let ctx = CGContext(data: nil,
                                  width: px,
                                  height: px,
                                  bitsPerComponent: 8,
                                  bytesPerRow: px * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            continue
        }
        ctx.interpolationQuality = .high
        ctx.draw(master, in: CGRect(x: 0, y: 0, width: px, height: px))

        guard let resized = ctx.makeImage() else { continue }

        let fileName = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        let fileURL = iconset.appendingPathComponent(fileName) as CFURL
        guard let dest = CGImageDestinationCreateWithURL(fileURL, "public.png" as CFString, 1, nil) else { continue }
        CGImageDestinationAddImage(dest, resized, nil)
        CGImageDestinationFinalize(dest)
    }
}
print("Successfully generated all iconset resolutions!")
