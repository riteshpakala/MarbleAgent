import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The photos the tests filter, and how they read a result's pixels back.
enum Fixture {
    struct Pixels {
        let width: Int
        let bytes: [UInt8]

        /// The red, green and blue at `x`, `y`, the top row first.
        func at(_ x: Int, _ y: Int) -> [Int] {
            let index = (y * width + x) * 4
            return [Int(bytes[index]), Int(bytes[index + 1]), Int(bytes[index + 2])]
        }
    }

    /// A 64 by 64 PNG in quadrants: white top left, black top right, red bottom left, gray bottom right.
    static func quadrants(at url: URL) throws {
        let size = 64
        var bytes = [UInt8](repeating: 255, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let color: [UInt8]
                switch (x < size / 2, y < size / 2) {
                case (true, true): color = [255, 255, 255]
                case (false, true): color = [0, 0, 0]
                case (true, false): color = [255, 0, 0]
                case (false, false): color = [128, 128, 128]
                }
                let index = (y * size + x) * 4
                bytes[index] = color[0]; bytes[index + 1] = color[1]; bytes[index + 2] = color[2]
            }
        }
        let image = try bytes.withUnsafeMutableBytes { raw -> CGImage in
            guard let made = context(raw.baseAddress, width: size, height: size)?.makeImage() else { throw CocoaError(.fileWriteUnknown) }
            return made
        }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    /// The pixels of the image at `url`, drawn into sRGB.
    static func pixels(of url: URL) throws -> Pixels {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let (width, height) = (image.width, image.height)
        bytes.withUnsafeMutableBytes { raw in
            context(raw.baseAddress, width: width, height: height)?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return Pixels(width: width, bytes: bytes)
    }

    private static func context(_ data: UnsafeMutableRawPointer?, width: Int, height: Int) -> CGContext? {
        CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
    }
}
