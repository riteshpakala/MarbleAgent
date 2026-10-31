import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A photo as the GPU takes it: 8-bit RGBA, premultiplied, in sRGB, the top row first; and the orientation
/// it was taken in, written back so the result is shown the same way up.
struct MarbleImage: Sendable {
    let width: Int
    let height: Int
    /// The source's EXIF orientation.
    let orientation: UInt32?
    var pixels: [UInt8]

    var bytesPerRow: Int { width * 4 }

    init(width: Int, height: Int, orientation: UInt32?) {
        self.width = width
        self.height = height
        self.orientation = orientation
        pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    /// The first image in the file at `url`, drawn into sRGB.
    init(contentsOf url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MarbleError.unreadable(url.path)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        self.init(width: image.width, height: image.height, orientation: (properties?[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value)
        let (width, height) = (self.width, self.height)
        let drawn: Bool = pixels.withUnsafeMutableBytes { bytes in
            guard let context = Self.context(bytes.baseAddress, width: width, height: height) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw MarbleError.unreadable(url.path) }
    }

    /// Writes the image to `url`, in the format its extension names, making its folder when there is none.
    func write(to url: URL) throws {
        guard let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) else {
            throw MarbleError.unwritable(url.path)
        }
        var copy = pixels
        let (width, height) = (self.width, self.height)
        let image = copy.withUnsafeMutableBytes { bytes in Self.context(bytes.baseAddress, width: width, height: height)?.makeImage() }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let image, let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw MarbleError.unwritable(url.path)
        }
        let properties: [CFString: Any] = orientation.map { [kCGImagePropertyOrientation: $0] } ?? [:]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw MarbleError.unwritable(url.path) }
    }

    private static func context(_ data: UnsafeMutableRawPointer?, width: Int, height: Int) -> CGContext? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
    }
}
