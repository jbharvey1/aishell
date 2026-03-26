import Foundation
import os

// ── Alfred REST client ─────────────────────────────────────────
// GET  http://<host>:<port>/health  → {"status":"ok"}  (instant, no LLM)
// POST http://<host>:<port>/chat    → {"response": "..."}
// Headers: Authorization: Bearer <key>, Content-Type: application/json

private let log = Logger(subsystem: "com.jbharvey1.AlfredChat", category: "AlfredMCPClient")

@MainActor
final class AlfredMCPClient: ObservableObject {
    @Published var isConnected  = false
    @Published var isThinking   = false
    @Published var errorMessage: String?

    private var host   = MCPConfig.defaultHost
    private var port   = MCPConfig.defaultPort
    private var apiKey = MCPConfig.defaultKey
    private var baseURL: URL { URL(string: "http://\(host):\(port)")! }

    // Separate sessions: fast timeout for health, generous for chat
    private lazy var healthSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 5
        cfg.timeoutIntervalForResource = 10
        return URLSession(configuration: cfg)
    }()

    private lazy var chatSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 90   // LLM can be slow
        cfg.timeoutIntervalForResource = 120
        return URLSession(configuration: cfg)
    }()

    // MARK: - connect (GET /health — instant, no LLM involvement)

    func connect(host: String, port: Int, apiKey: String) async {
        self.host   = host
        self.port   = port
        self.apiKey = apiKey
        errorMessage = nil
        isConnected  = false

        log.info("Connecting to \(host):\(port)")
        do {
            let url = baseURL.appendingPathComponent("health")
            var req = URLRequest(url: url)
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            let (_, response) = try await healthSession.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                log.info("Connected — health check OK")
                isConnected = true
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                log.error("Health check failed — HTTP \(code)")
                throw AlfredError.server("Health check failed (HTTP \(code))")
            }
        } catch {
            log.error("Connection error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        log.info("Disconnected")
        isConnected = false
    }

    func sendMessage(_ text: String) async throws -> String {
        guard isConnected else {
            log.error("sendMessage called while not connected")
            throw AlfredError.notConnected
        }
        log.info("Sending message (\(text.count) chars)")
        isThinking = true
        defer { isThinking = false }
        let reply = try await post(message: text)
        log.info("Reply received (\(reply.count) chars)")
        return reply
    }

    // MARK: - internal

    private func post(message: String) async throws -> String {
        let url  = baseURL.appendingPathComponent("chat")
        var req  = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["message": message])

        log.debug("POST \(url)")
        let (data, response) = try await chatSession.data(for: req)

        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            log.error("Server error HTTP \(http.statusCode): \(body)")
            throw AlfredError.server("HTTP \(http.statusCode): \(body)")
        }

        guard let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = obj["response"] as? String else {
            log.error("Bad response — could not parse JSON")
            throw AlfredError.badResponse
        }
        return text
    }
}

enum AlfredError: LocalizedError {
    case notConnected, badResponse, server(String)
    var errorDescription: String? {
        switch self {
        case .notConnected:    return "Not connected to Alfred"
        case .badResponse:     return "Unexpected response from Alfred"
        case .server(let msg): return msg
        }
    }
}
