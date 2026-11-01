import SwiftUI
import UIKit
import ReceiptKit

// Colour tokens from the Figma file (Color variable collection). Names follow the Figma
// variables' iOS code syntax, e.g. color/bg/primary → Color.bgPrimary.
extension Color {
    static let bgPrimary = Color(light: 0xF5F6F8, dark: 0x000000)
    static let bgSurface = Color(light: 0xFFFFFF, dark: 0x17191C)
    static let bgSurfaceSecondary = Color(light: 0xECEEF2, dark: 0x2C2F34)
    static let textPrimary = Color(light: 0x0E0F11, dark: 0xFFFFFF)
    static let textSecondary = Color(light: 0x6B7280, dark: 0x9AA1AD)
    /// Text and icons on top of the accent colour (dark text on the bright dark-mode green).
    static let textOnAccent = Color(light: 0xFFFFFF, dark: 0x0E0F11)
    static let borderDefault = Color(light: 0xE2E5EA, dark: 0x2C2F34)
    static let accentDefault = Color(light: 0x0E8A5F, dark: 0x3DD68C)
    static let accentSubtle = Color(light: 0xDDF5EA, dark: 0x0B3B2A)
    static let statusNegative = Color(light: 0xE5484D, dark: 0xFB7185)
    static let statusWarning = Color(light: 0xE5A00D, dark: 0xE5A00D)

    static let categoryFood = Color(light: 0xF2711C, dark: 0xFB923C)
    static let categoryUtilities = Color(light: 0x2F6FEB, dark: 0x60A5FA)
    static let categoryHealth = Color(light: 0xE5484D, dark: 0xFB7185)
    static let categoryTransport = Color(light: 0x7C5CFA, dark: 0xA78BFA)
    static let categoryOther = Color(light: 0x64748B, dark: 0x94A3B8)

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension SpendCategory {
    var color: Color {
        switch self {
        case .food: .categoryFood
        case .utilities: .categoryUtilities
        case .health: .categoryHealth
        case .transport: .categoryTransport
        case .other: .categoryOther
        }
    }

    /// Light background behind category icons and pills (14% in light mode, 20% in dark, as in Figma).
    var tint: Color {
        let base = UIColor(color)
        return Color(uiColor: UIColor { traits in
            base.resolvedColor(with: traits).withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.20 : 0.14)
        })
    }
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 20
}

extension Decimal {
    /// "£1,284.60"
    var gbp: String {
        formatted(.currency(code: "GBP").locale(Locale(identifier: "en_GB")))
    }
}
