import SwiftUI

/// Convenience initializer to create a Color from a hex string.
/// Supports "RRGGBB", "#RRGGBB", "AARRGGBB", and "#AARRGGBB" formats.
public extension Color {
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        let chars = Array(hexString)
        guard chars.count == 6 || chars.count == 8 else { return nil }

        var a: UInt64 = 255
        var r: UInt64 = 0
        var g: UInt64 = 0
        var b: UInt64 = 0

        func value(from start: Int, length: Int) -> UInt64? {
            let end = start + length
            let slice = String(chars[start..<end])
            return UInt64(slice, radix: 16)
        }

        if chars.count == 6 {
            guard let rr = value(from: 0, length: 2),
                  let gg = value(from: 2, length: 2),
                  let bb = value(from: 4, length: 2) else { return nil }
            r = rr; g = gg; b = bb
        } else {
            guard let aa = value(from: 0, length: 2),
                  let rr = value(from: 2, length: 2),
                  let gg = value(from: 4, length: 2),
                  let bb = value(from: 6, length: 2) else { return nil }
            a = aa; r = rr; g = gg; b = bb
        }

        let rf = Double(r) / 255.0
        let gf = Double(g) / 255.0
        let bf = Double(b) / 255.0
        let af = Double(a) / 255.0

        self = Color(.sRGB, red: rf, green: gf, blue: bf, opacity: af)
    }

    /// Convenience unlabeled initializer forwarding to `init(hex:)`.
    init?(_ hex: String) {
        self.init(hex: hex)
    }
}
