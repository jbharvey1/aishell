import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp: Date

    enum Role { case user, alfred, system }
}

struct MCPConfig {
    static let defaultHost = "192.168.1.1"
    static let defaultPort = 8422
    static let defaultKey  = "change-me"
}
