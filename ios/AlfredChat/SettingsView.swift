import SwiftUI

struct SettingsView: View {
    @Binding var host: String
    @Binding var port: Int
    @Binding var apiKey: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var portString: String = ""
    @State private var showKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Alfred Server") {
                    LabeledContent("Host") {
                        TextField("192.168.1.1", text: $host)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                    LabeledContent("Port") {
                        TextField("8422", text: $portString)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .onChange(of: portString) { _ in
                                if let n = Int(portString) { port = n }
                            }
                    }
                }

                Section("Authentication") {
                    HStack {
                        if showKey {
                            TextField("API Key", text: $apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("API Key", text: $apiKey)
                                .font(.system(.body, design: .monospaced))
                        }
                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button("Reset to Defaults") {
                        host = MCPConfig.defaultHost
                        port = MCPConfig.defaultPort
                        portString = String(MCPConfig.defaultPort)
                        apiKey = MCPConfig.defaultKey
                    }
                    .foregroundStyle(.orange)
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alfred MCP Server").font(.caption.bold())
                        Text("Connects via MCP over SSE protocol. Alfred must be running on your local network.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                portString = String(port)
            }
        }
    }
}
