import Foundation

/// The built-in spending categories. Stored by `rawValue`, so never rename a case.
public enum SpendCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case food
    case utilities
    case health
    case transport
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .food: "Food"
        case .utilities: "Utilities"
        case .health: "Health"
        case .transport: "Transport"
        case .other: "Other"
        }
    }

    /// SF Symbol used for the category icon.
    public var symbolName: String {
        switch self {
        case .food: "basket"
        case .utilities: "bolt"
        case .health: "cross"
        case .transport: "bus"
        case .other: "ellipsis"
        }
    }
}
