import Foundation
import Vision
import UIKit

/// Runs on-device text recognition over a receipt photo and hands the
/// recognized text to `ExpenseParsingService` for the same amount/date/
/// category extraction used by typed natural-language entry — a receipt is
/// just another source of text, not a separate pipeline. Nothing here
/// leaves the device: `VNRecognizeTextRequest` runs entirely locally.
@MainActor
final class ReceiptScanService {
    static let shared = ReceiptScanService()

    private init() {}

    enum ScanError: LocalizedError {
        case invalidImage
        case recognitionFailed(String)
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "That doesn't look like a valid image."
            case .recognitionFailed(let reason): return "Couldn't read the receipt: \(reason)"
            case .noTextFound: return "No text found on that receipt. Try a clearer photo."
            }
        }
    }

    /// Recognizes text in the given receipt image and parses it into a
    /// draft expense. Always feeds through the same confirmation sheet as
    /// manual/NL entry — OCR is even more error-prone than typed text
    /// (crumpled receipts, thermal-printer fade), so nothing here is ever
    /// auto-saved.
    func scan(image: UIImage) async throws -> ParsedExpenseDraft {
        guard let cgImage = image.cgImage else {
            throw ScanError.invalidImage
        }

        let recognizedText = try await recognizeText(in: cgImage)
        guard !recognizedText.isEmpty else {
            throw ScanError.noTextFound
        }

        // Receipts are typically dominated by line items and a final total;
        // bias amount extraction toward the largest currency-looking number
        // on the receipt (usually the total), which `extractAmount`'s
        // fallback-to-max behavior already does well when given the whole
        // block of recognized lines.
        var draft = ExpenseParsingService.shared.parse(recognizedText)
        draft.notes = recognizedText
        return draft
    }

    private func recognizeText(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: ScanError.recognitionFailed(error.localizedDescription))
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ScanError.recognitionFailed(error.localizedDescription))
            }
        }
    }
}
