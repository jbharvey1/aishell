import Foundation

public struct ChatMessage: Identifiable, Equatable {
    public let id = UUID()
    public let role: Role
    public let text: String
    public let timestamp: Date

    public enum Role: Equatable { case user, alfred, system }

    public init(role: Role, text: String, timestamp: Date) {
        self.role = role; self.text = text; self.timestamp = timestamp
    }
}

public struct MCPConfig {
    public static let defaultHost = "192.168.1.1"
    public static let defaultPort = 8422
    public static let defaultKey  = "change-me"
}

public enum AlfredError: LocalizedError, Equatable {
    case notConnected, badResponse, server(String)
    public var errorDescription: String? {
        switch self {
        case .notConnected:    return "Not connected to Alfred"
        case .badResponse:     return "Unexpected response from Alfred"
        case .server(let msg): return msg
        }
    }
}
