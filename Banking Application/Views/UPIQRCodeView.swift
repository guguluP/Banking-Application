import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct UPIQRCodeView: View {
    let payload: String

    var body: some View {
        VStack(spacing: 16) {
            Text("UPI QR")
                .font(.headline)
            if let image = Self.image(for: payload) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
            }
            Text(payload)
                .font(.caption)
                .multilineTextAlignment(.center)
            Text("Scan this in a UPI app. This demo does not register a real VPA.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    static func image(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
