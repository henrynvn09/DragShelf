import Foundation
import Vision
import AppKit

/// Recognizes text from images using the Vision framework.
final class TextRecognizer {

    // MARK: - Synchronous (callback-based)

    /// Performs OCR on the image at the given URL.
    /// Calls completion with the recognized text, or nil on failure.
    static func recognizeText(in imageURL: URL, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = loadCGImage(from: imageURL) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation]
                else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = recognizedStrings.joined(separator: "\n")

                DispatchQueue.main.async {
                    completion(fullText.isEmpty ? nil : fullText)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            do {
                try requestHandler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    // MARK: - Async wrapper

    /// Async wrapper around `recognizeText(in:completion:)`.
    static func recognizeTextAsync(in imageURL: URL) async -> String? {
        await withCheckedContinuation { continuation in
            recognizeText(in: imageURL) { text in
                continuation.resume(returning: text)
            }
        }
    }

    // MARK: - Private

    /// Loads a CGImage from a URL using CGImageSource.
    private static func loadCGImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
