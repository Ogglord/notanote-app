import Foundation

/// Identifies where a todo item originated from
public enum TodoSource: String, CaseIterable, Codable, Identifiable {
    case manual = "manual"
    case linear = "linear"
    case pylon = "pylon"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .manual: return "My Todos"
        case .linear: return "Linear"
        case .pylon: return "Pylon"
        }
    }

    /// Detect source from a todo item's tags
    public static func detect(from tags: [String]) -> TodoSource {
        if tags.contains(where: { $0.lowercased() == "linear" }) {
            return .linear
        }
        if tags.contains(where: { $0.lowercased() == "pylon" }) {
            return .pylon
        }
        return .manual
    }

    // MARK: - Source Order (persisted)

    private static let orderKey = "sourceOrder"

    /// The default ordering: manual first, then linear, then pylon
    public static let defaultOrder: [TodoSource] = [.manual, .linear, .pylon]

    /// Read the user-configured source order from UserDefaults
    public static var savedOrder: [TodoSource] {
        guard let data = UserDefaults.standard.data(forKey: orderKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return defaultOrder
        }
        let mapped = decoded.compactMap { TodoSource(rawValue: $0) }
        // Ensure all sources are represented (in case a new one was added)
        let missing = defaultOrder.filter { !mapped.contains($0) }
        return mapped + missing
    }

    /// Persist a new source order to UserDefaults
    public static func saveOrder(_ order: [TodoSource]) {
        let raw = order.map(\.rawValue)
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: orderKey)
        }
    }

    /// Sort rank for this source (0-based index in the saved order -- lower = higher priority)
    public var sortRank: Int {
        Self.savedOrder.firstIndex(of: self) ?? Self.allCases.count
    }
}
