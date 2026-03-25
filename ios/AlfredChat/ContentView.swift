import SwiftUI

struct ContentView: View {
    @StateObject private var client = AlfredMCPClient()
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var showSettings = false
    @State private var isConnecting = false
    @FocusState private var inputFocused: Bool

    @AppStorage("alfred_host")   private var host   = MCPConfig.defaultHost
    @AppStorage("alfred_port")   private var port   = MCPConfig.defaultPort
    @AppStorage("alfred_apikey") private var apiKey = MCPConfig.defaultKey

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBanner
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(messages) { msg in
                                MessageBubble(message: msg).id(msg.id)
                            }
                            if client.isThinking { ThinkingBubble() }
                        }
                        .padding(.horizontal).padding(.top, 8).padding(.bottom, 12)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: client.isThinking) { _ in
                        withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                inputBar
            }
            .background(Color(.systemBackground))
            .navigationTitle("Alfred")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { connectionButton }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gear") }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(host: $host, port: $port, apiKey: $apiKey) {
                    Task { await reconnect() }
                }
            }
        }
        .task {
            await reconnect()
            // Dev/test: inject fake Alfred replies via --test-inject "markdown" launch args
            // Usage: xcrun simctl launch booted com.jbharvey.AlfredChat --args --test-inject "**bold**"
            let args = ProcessInfo.processInfo.arguments
            var i = 1
            while i < args.count {
                if args[i] == "--test-inject", i + 1 < args.count {
                    let md = args[i + 1]
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    messages.append(ChatMessage(role: .alfred, text: md, timestamp: .now))
                    i += 2
                } else { i += 1 }
            }
        }
        // alfredchat://inject?markdown=... injects a fake Alfred reply (dev/test only)
        .onOpenURL { url in
            guard url.scheme == "alfredchat",
                  url.host == "inject",
                  let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let md = comps.queryItems?.first(where: { $0.name == "markdown" })?.value,
                  let decoded = md.removingPercentEncoding
            else { return }
            messages.append(ChatMessage(role: .alfred, text: decoded, timestamp: .now))
        }
    }

    // MARK: - Sub-views

    private var statusBanner: some View {
        Group {
            if let err = client.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(err).font(.caption)
                    Spacer()
                    Button("Retry") { Task { await reconnect() } }.font(.caption.bold())
                }
                .padding(.horizontal).padding(.vertical, 6)
                .background(Color.red.opacity(0.15)).foregroundStyle(.red)
            } else if isConnecting {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("Connecting to Alfred\u{2026}").font(.caption)
                }
                .padding(.horizontal).padding(.vertical, 6)
                .background(Color.orange.opacity(0.1)).foregroundStyle(.orange)
            }
        }
    }

    private var connectionButton: some View {
        Button {
            Task {
                if client.isConnected { client.disconnect() }
                else { await reconnect() }
            }
        } label: {
            Image(systemName: client.isConnected ? "wifi" : "wifi.slash")
                .foregroundStyle(client.isConnected ? .green : .secondary)
        }
        .disabled(isConnecting)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message Alfred\u{2026}", text: $inputText, axis: .vertical)
                .lineLimit(1...5).textFieldStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($inputFocused).onSubmit { sendIfPossible() }
            Button(action: sendIfPossible) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? .blue : .secondary)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && client.isConnected && !client.isThinking
    }

    // MARK: - Actions

    private func reconnect() async {
        isConnecting = true
        defer { isConnecting = false }
        await client.connect(host: host, port: port, apiKey: apiKey)
        if client.isConnected { addSystem("Connected to Alfred.") }
    }

    private func sendIfPossible() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, canSend else { return }
        inputText = ""
        inputFocused = false
        messages.append(ChatMessage(role: .user, text: text, timestamp: .now))
        Task {
            do {
                let reply = try await client.sendMessage(text)
                messages.append(ChatMessage(role: .alfred, text: reply, timestamp: .now))
            } catch {
                addSystem("Error: \(error.localizedDescription)")
            }
        }
    }

    private func addSystem(_ text: String) {
        messages.append(ChatMessage(role: .system, text: text, timestamp: .now))
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.role == .user { Spacer(minLength: 50) }
            if message.role == .alfred {
                Image(systemName: "person.circle.fill").font(.title2).foregroundStyle(.purple)
            }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                bubbleContent
                Text(message.timestamp, style: .time)
                    .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            if message.role != .user { Spacer(minLength: 50) }
            if message.role == .user {
                Image(systemName: "person.circle.fill").font(.title2).foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if message.role == .alfred {
            MarkdownMessageView(text: message.text)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            Text(message.text)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(message.role == .user ? Color.blue : Color(.tertiarySystemBackground))
                .foregroundStyle(message.role == .user ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .textSelection(.enabled)
        }
    }
}

// MARK: - Markdown Message View

struct MarkdownMessageView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks(text).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        // Force links to open in the user's default browser (not in-app)
        .environment(\.openURL, OpenURLAction { url in
            UIApplication.shared.open(url)
            return .handled
        })
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .text(let content):
            markdownText(content)

        case .code(let lang, let content):
            VStack(alignment: .leading, spacing: 0) {
                if let lang, !lang.isEmpty {
                    Text(lang)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10).padding(.top, 6).padding(.bottom, 2)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(content)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                }
            }
            .background(Color(.systemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        case .image(let urlString, let alt):
            VStack(alignment: .leading, spacing: 4) {
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            Label("Image unavailable", systemImage: "photo.slash")
                                .foregroundStyle(.secondary).font(.caption)
                        case .empty:
                            HStack {
                                ProgressView()
                                Text("Loading image...").font(.caption).foregroundStyle(.secondary)
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                if !alt.isEmpty {
                    Text(alt).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func markdownText(_ content: String) -> some View {
        let opts = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attr = try? AttributedString(markdown: content, options: opts) {
            Text(attr).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        } else {
            Text(content).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Block types

    enum Block {
        case text(String)
        case code(String?, String)   // (language?, content)
        case image(String, String)   // (url, alt)
    }

    // MARK: - Parser

    private func parseBlocks(_ input: String) -> [Block] {
        var result: [Block] = []
        var remaining = input

        while !remaining.isEmpty {
            let codeStart  = remaining.range(of: "```")
            let imageStart = remaining.range(of: #"!\[[^\]]*\]\([^)]+\)"#, options: .regularExpression)

            let nextIsCode: Bool?
            if let c = codeStart, let i = imageStart {
                nextIsCode = c.lowerBound <= i.lowerBound
            } else if codeStart != nil  { nextIsCode = true  }
            else if imageStart != nil   { nextIsCode = false }
            else                        { nextIsCode = nil   }

            guard let isCode = nextIsCode else {
                if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(.text(remaining))
                }
                break
            }

            if isCode, let startRange = codeStart {
                let before = String(remaining[..<startRange.lowerBound])
                if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(.text(before))
                }
                let afterOpen = String(remaining[startRange.upperBound...])
                if let endRange = afterOpen.range(of: "```") {
                    var body = String(afterOpen[..<endRange.lowerBound])
                    var lang: String? = nil
                    let lines = body.components(separatedBy: "\n")
                    if let first = lines.first,
                       !first.trimmingCharacters(in: .whitespaces).isEmpty,
                       !first.contains(" "), first.count <= 20 {
                        lang = first.trimmingCharacters(in: .whitespaces)
                        body = lines.dropFirst().joined(separator: "\n")
                    }
                    result.append(.code(lang, body.trimmingCharacters(in: .newlines)))
                    remaining = String(afterOpen[endRange.upperBound...])
                } else {
                    result.append(.text("```" + afterOpen))
                    break
                }
            } else if let iRange = imageStart {
                let before = String(remaining[..<iRange.lowerBound])
                if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(.text(before))
                }
                let imgMd = String(remaining[iRange])
                let alt = imgMd.range(of: #"(?<=!\[)[^\]]*"#, options: .regularExpression)
                    .map { String(imgMd[$0]) } ?? ""
                let url = imgMd.range(of: #"(?<=\()[^)]+"#, options: .regularExpression)
                    .map { String(imgMd[$0]) } ?? ""
                if !url.isEmpty { result.append(.image(url, alt)) }
                remaining = String(remaining[iRange.upperBound...])
            }
        }

        return result
    }
}

// MARK: - Thinking Bubble

struct ThinkingBubble: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Image(systemName: "person.circle.fill").font(.title2).foregroundStyle(.purple)
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .frame(width: 7, height: 7).foregroundStyle(.secondary)
                        .scaleEffect(animate ? 1.3 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer(minLength: 50)
        }
        .id("thinking")
        .onAppear { animate = true }
    }
}

#Preview { ContentView() }
