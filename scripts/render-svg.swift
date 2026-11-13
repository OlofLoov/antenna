// Renders an SVG to a PNG of an exact pixel size with AppKit: render-svg.swift <in.svg> <out.png> <width> <height> [opaque]
import AppKit
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 5, let width = Int(arguments[3]), let height = Int(arguments[4]) else {
    FileHandle.standardError.write(Data("usage: render-svg.swift <in.svg> <out.png> <width> <height> [opaque]\n".utf8))
    exit(2)
}
let opaque = arguments.count > 5 && arguments[5] == "opaque"
guard let image = NSImage(contentsOf: URL(fileURLWithPath: arguments[1])) else {
    FileHandle.standardError.write(Data("cannot read \(arguments[1])\n".utf8))
    exit(1)
}
let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
guard
    let space = CGColorSpace(name: CGColorSpace.sRGB),
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: alpha.rawValue)
else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
NSGraphicsContext.restoreGraphicsState()
guard
    let rendered = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: arguments[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(destination, rendered, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
