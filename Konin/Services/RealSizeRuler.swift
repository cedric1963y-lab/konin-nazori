import SwiftUI
import UIKit

/// Converts millimetres to on-screen points using a model -> pixel density table,
/// then a user correction measured against a 54.0 x 85.6 mm card.
@MainActor
final class RealSizeRuler: ObservableObject {
    @Published var correction: Double {
        didSet { UserDefaults.standard.set(correction, forKey: "ruler.correction") }
    }

    let modelCode: String
    let modelName: String
    let pixelsPerInch: Double?

    init() {
        let code = Self.readModelCode()
        modelCode = code
        let entry = Self.table[code]
        modelName = entry?.name ?? "この機種"
        pixelsPerInch = entry?.ppi
        let saved = UserDefaults.standard.double(forKey: "ruler.correction")
        correction = saved == 0 ? 1.0 : saved
    }

    var isKnownModel: Bool { pixelsPerInch != nil }

    private var nativeScale: Double { Double(UIScreen.main.nativeScale) }

    /// Points per millimetre before the user correction.
    var basePointsPerMM: Double {
        let ppi = pixelsPerInch ?? (nativeScale >= 2.9 ? 460 : 326)
        return ppi / nativeScale / 25.4
    }

    var pointsPerMM: Double { basePointsPerMM * correction }

    func pt(_ mm: Double) -> CGFloat { CGFloat(mm * pointsPerMM) }

    var correctionLabel: String {
        let pct = (correction - 1) * 100
        let sign = pct >= 0 ? "＋" : "−"
        return String(format: "%@%.1f%%", sign, abs(pct))
    }

    private static func readModelCode() -> String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    private static let table: [String: (name: String, ppi: Double)] = [
        "iPhone10,1": ("iPhone 8", 326), "iPhone10,4": ("iPhone 8", 326),
        "iPhone10,2": ("iPhone 8 Plus", 401), "iPhone10,5": ("iPhone 8 Plus", 401),
        "iPhone10,3": ("iPhone X", 458), "iPhone10,6": ("iPhone X", 458),
        "iPhone11,2": ("iPhone XS", 458), "iPhone11,4": ("iPhone XS Max", 458),
        "iPhone11,6": ("iPhone XS Max", 458), "iPhone11,8": ("iPhone XR", 326),
        "iPhone12,1": ("iPhone 11", 326), "iPhone12,3": ("iPhone 11 Pro", 458),
        "iPhone12,5": ("iPhone 11 Pro Max", 458), "iPhone12,8": ("iPhone SE（第2世代）", 326),
        "iPhone13,1": ("iPhone 12 mini", 476), "iPhone13,2": ("iPhone 12", 460),
        "iPhone13,3": ("iPhone 12 Pro", 460), "iPhone13,4": ("iPhone 12 Pro Max", 458),
        "iPhone14,4": ("iPhone 13 mini", 476), "iPhone14,5": ("iPhone 13", 460),
        "iPhone14,2": ("iPhone 13 Pro", 460), "iPhone14,3": ("iPhone 13 Pro Max", 458),
        "iPhone14,6": ("iPhone SE（第3世代）", 326),
        "iPhone14,7": ("iPhone 14", 460), "iPhone14,8": ("iPhone 14 Plus", 458),
        "iPhone15,2": ("iPhone 14 Pro", 460), "iPhone15,3": ("iPhone 14 Pro Max", 460),
        "iPhone15,4": ("iPhone 15", 460), "iPhone15,5": ("iPhone 15 Plus", 460),
        "iPhone16,1": ("iPhone 15 Pro", 460), "iPhone16,2": ("iPhone 15 Pro Max", 460),
        "iPhone17,3": ("iPhone 16", 460), "iPhone17,4": ("iPhone 16 Plus", 460),
        "iPhone17,1": ("iPhone 16 Pro", 460), "iPhone17,2": ("iPhone 16 Pro Max", 460),
        "iPhone17,5": ("iPhone 16e", 460),
        "iPhone18,3": ("iPhone 17", 460), "iPhone18,1": ("iPhone 17 Pro", 460),
        "iPhone18,2": ("iPhone 17 Pro Max", 460), "iPhone18,4": ("iPhone Air", 460)
    ]
}

/// Keeps the screen at full brightness and awake while tracing, then restores it.
@MainActor
final class TracingScreenGuard {
    private var savedBrightness: CGFloat?
    private var savedIdle = false

    func engage() {
        if savedBrightness == nil {
            savedBrightness = UIScreen.main.brightness
            savedIdle = UIApplication.shared.isIdleTimerDisabled
        }
        UIScreen.main.brightness = 1.0
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func release() {
        if let b = savedBrightness { UIScreen.main.brightness = b }
        UIApplication.shared.isIdleTimerDisabled = savedIdle
        savedBrightness = nil
    }
}
