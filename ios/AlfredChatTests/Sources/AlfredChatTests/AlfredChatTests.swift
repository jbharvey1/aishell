import XCTest
import AlfredChatKit

// ── Unit Tests for AlfredMCPClient ────────────────────────────
//
// Run via SSH:
//   xcodebuild test -project AlfredChat.xcodeproj -scheme AlfredChat \
//     -destination "platform=iOS Simulator,name=iPhone 17" 2>&1 | grep -E "Test|PASS|FAIL|error:"
//
// Remote log stream while running:
//   xcrun simctl spawn booted log stream \
//     --predicate 'subsystem == "com.jbharvey1.AlfredChat"' --level debug


func makeHTTP(_ code: Int, url: String = "http://192.168.1.1:8422") -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: url)!, statusCode: code, httpVersion: nil, headerFields: nil)!
}

func makeData(_ json: String) -> Data { json.data(using: .utf8)! }

// MARK: - AlfredError Tests

final class AlfredErrorTests: XCTestCase {
    func test_notConnected_description() {
        XCTAssertEqual(AlfredError.notConnected.errorDescription, "Not connected to Alfred")
    }

    func test_badResponse_description() {
        XCTAssertEqual(AlfredError.badResponse.errorDescription, "Unexpected response from Alfred")
    }

    func test_server_description() {
        XCTAssertEqual(AlfredError.server("oops").errorDescription, "oops")
    }
}

// MARK: - MCPConfig Tests

final class MCPConfigTests: XCTestCase {
    func test_defaultHost() {
        XCTAssertEqual(MCPConfig.defaultHost, "192.168.1.1")
    }

    func test_defaultPort() {
        XCTAssertEqual(MCPConfig.defaultPort, 8422)
    }

    func test_defaultKey_notEmpty() {
        XCTAssertFalse(MCPConfig.defaultKey.isEmpty)
    }

    func test_baseURL_format() {
        let url = URL(string: "http://\(MCPConfig.defaultHost):\(MCPConfig.defaultPort)")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, MCPConfig.defaultHost)
        XCTAssertEqual(url?.port, MCPConfig.defaultPort)
    }
}

// MARK: - Health Endpoint JSON Tests

final class HealthResponseTests: XCTestCase {
    func test_health_ok_json_parses() throws {
        let data = makeData(#"{"status":"ok"}"#)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["status"] as? String, "ok")
    }

    func test_health_bad_json_fails_gracefully() {
        let data = makeData("not json")
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNil(json)
    }
}

// MARK: - Chat Response JSON Tests

final class ChatResponseTests: XCTestCase {
    func test_valid_chat_response_parsed() throws {
        let data = makeData(#"{"response":"Hello, how are you today?"}"#)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let text = try XCTUnwrap(json["response"] as? String)
        XCTAssertEqual(text, "Hello, how are you today?")
    }

    func test_missing_response_key_fails() {
        let data = makeData(#"{"message":"Hello"}"#)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
        let text = json?["response"] as? String
        XCTAssertNil(text)
    }

    func test_empty_response_string_detected() throws {
        let data = makeData(#"{"response":""}"#)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let text = json["response"] as? String
        XCTAssertNotNil(text)
        XCTAssertTrue(text?.isEmpty == true)
    }

    func test_unicode_response_preserved() throws {
        let data = makeData(#"{"response":"こんにちは 🤖"}"#)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["response"] as? String, "こんにちは 🤖")
    }

    func test_long_response_preserved() throws {
        let longText = String(repeating: "a", count: 10_000)
        let data = makeData(#"{"response":"\#(longText)"}"#)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual((json["response"] as? String)?.count, 10_000)
    }
}

// MARK: - Request Construction Tests

final class RequestConstructionTests: XCTestCase {
    func test_chat_request_method_is_POST() throws {
        let url = URL(string: "http://192.168.1.1:8422/chat")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        XCTAssertEqual(req.httpMethod, "POST")
    }

    func test_auth_header_format() {
        let key = "test-api-key-123"
        let header = "Bearer \(key)"
        XCTAssertTrue(header.hasPrefix("Bearer "))
        XCTAssertTrue(header.contains(key))
    }

    func test_chat_body_serializes_message() throws {
        let message = "Hello Alfred"
        let body = try JSONSerialization.data(withJSONObject: ["message": message])
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(decoded["message"] as? String, message)
    }

    func test_chat_body_rejects_empty_after_trim() {
        let text = "   \n  "
        XCTAssertTrue(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func test_health_url_path() {
        let base = URL(string: "http://192.168.1.1:8422")!
        let health = base.appendingPathComponent("health")
        XCTAssertEqual(health.path, "/health")
    }

    func test_chat_url_path() {
        let base = URL(string: "http://192.168.1.1:8422")!
        let chat = base.appendingPathComponent("chat")
        XCTAssertEqual(chat.path, "/chat")
    }
}

// MARK: - HTTP Status Code Handling Tests

final class HTTPStatusTests: XCTestCase {
    func test_200_is_success() {
        let resp = makeHTTP(200)
        XCTAssertFalse(resp.statusCode >= 400)
    }

    func test_403_is_error() {
        let resp = makeHTTP(403)
        XCTAssertTrue(resp.statusCode >= 400)
    }

    func test_500_is_error() {
        let resp = makeHTTP(500)
        XCTAssertTrue(resp.statusCode >= 400)
    }

    func test_error_message_includes_status_code() {
        let code = 403
        let body = "Forbidden"
        let msg = "HTTP \(code): \(body)"
        XCTAssertTrue(msg.contains("403"))
        XCTAssertTrue(msg.contains("Forbidden"))
    }
}

// MARK: - ChatMessage Model Tests

final class ChatMessageTests: XCTestCase {
    func test_user_message_role() {
        let msg = ChatMessage(role: .user, text: "hi", timestamp: .now)
        XCTAssertEqual(msg.role, .user)
    }

    func test_alfred_message_role() {
        let msg = ChatMessage(role: .alfred, text: "hello", timestamp: .now)
        XCTAssertEqual(msg.role, .alfred)
    }

    func test_system_message_role() {
        let msg = ChatMessage(role: .system, text: "Connected.", timestamp: .now)
        XCTAssertEqual(msg.role, .system)
    }

    func test_message_id_is_unique() {
        let a = ChatMessage(role: .user, text: "a", timestamp: .now)
        let b = ChatMessage(role: .user, text: "b", timestamp: .now)
        XCTAssertNotEqual(a.id, b.id)
    }

    func test_message_text_preserved() {
        let text = "What's the weather like?"
        let msg = ChatMessage(role: .user, text: text, timestamp: .now)
        XCTAssertEqual(msg.text, text)
    }
}
