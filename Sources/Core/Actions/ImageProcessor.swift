import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import AppKit

/// Image processing utilities using Image I/O framework.
final class ImageProcessor {

    // MARK: - ImageFormat

    enum ImageFormat {
        case jpeg
        case png
        case heic

        var utType: UTType {
            switch self {
            case .jpeg: return .jpeg
            case .png:  return .png
            case .heic: return .heic
            }
        }

        var fileExtension: String {
            switch self {
            case .jpeg: return "jpg"
            case .png:  return "png"
            case .heic: return "heic"
            }
        }
    }

    // MARK: - Convert

    /// Converts an image at the given URL to the specified format.
    /// Returns the URL of the converted file, or nil on failure.
    static func convertImage(at url: URL, to format: ImageFormat, outputDirectory: URL) -> URL? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let baseName = url.deletingPathExtension().lastPathComponent
        let outputURL = outputDirectory
            .appendingPathComponent(baseName)
            .appendingPathExtension(format.fileExtension)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            format.utType.identifier as CFString,
            1,
            nil
        ) else { return nil }

        var options: [CFString: Any] = [:]
        if format == .jpeg {
            options[kCGImageDestinationLossyCompressionQuality] = 0.85
        }

        CGImageDestinationAddImageFromSource(destination, source, 0, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return outputURL
    }

    // MARK: - Resize

    /// Resizes an image by the given scale factor (e.g. 0.5 for 50%).
    /// Returns the URL of the resized file, or nil on failure.
    static func resizeImage(at url: URL, scale: CGFloat, outputDirectory: URL) -> URL? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let originalWidth = imageProperties[kCGImagePropertyPixelWidth] as? CGFloat,
              let originalHeight = imageProperties[kCGImagePropertyPixelHeight] as? CGFloat
        else { return nil }

        let newWidth = Int(originalWidth * scale)
        let newHeight = Int(originalHeight * scale)

        guard newWidth > 0, newHeight > 0 else { return nil }

        // Decode the source image
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        // Create a bitmap context and draw the scaled image
        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: newWidth,
                  height: newHeight,
                  bitsPerComponent: cgImage.bitsPerComponent,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: cgImage.alphaInfo.rawValue
              )
        else { return nil }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let scaledImage = context.makeImage() else { return nil }

        // Determine output format from the source file extension
        let ext = url.pathExtension.lowercased()
        let utType: UTType
        switch ext {
        case "png":                 utType = .png
        case "heic":                utType = .heic
        case "jpg", "jpeg":         utType = .jpeg
        default:                    utType = .png
        }

        let baseName = url.deletingPathExtension().lastPathComponent
        let outputURL = outputDirectory
            .appendingPathComponent("\(baseName)_\(Int(scale * 100))pct")
            .appendingPathExtension(ext)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else { return nil }

        var options: [CFString: Any] = [:]
        if utType == .jpeg {
            options[kCGImageDestinationLossyCompressionQuality] = 0.85
        }

        CGImageDestinationAddImage(destination, scaledImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return outputURL
    }

    // MARK: - Strip Metadata

    /// Copies an image but removes EXIF, GPS, and IPTC metadata.
    /// Returns the URL of the cleaned file, or nil on failure.
    static func stripMetadata(at url: URL, outputDirectory: URL) -> URL? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let sourceType = CGImageSourceGetType(source) else { return nil }

        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let outputURL = outputDirectory
            .appendingPathComponent("\(baseName)_clean")
            .appendingPathExtension(ext)

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            sourceType,
            1,
            nil
        ) else { return nil }

        // Copy the original properties and strip sensitive dictionaries
        var properties: [String: Any] = [:]
        if let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            properties = sourceProperties
        }

        // Remove metadata dictionaries
        properties.removeValue(forKey: kCGImagePropertyExifDictionary as String)
        properties.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
        properties.removeValue(forKey: kCGImagePropertyIPTCDictionary as String)
        properties.removeValue(forKey: kCGImagePropertyMakerAppleDictionary as String)

        CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return outputURL
    }
}
