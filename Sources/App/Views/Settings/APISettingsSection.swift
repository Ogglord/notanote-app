import SwiftUI
import Networking

// MARK: - Linear Settings

struct LinearSettingsSection: View {
    @AppStorage("linear.enabled") private var linearEnabled: Bool = false
    @State private var token: String = ""
    @State private var testStatus: ConnectionTestStatus = .idle

    private static let keychainAccount = "linear-api-token"

    var body: some View {
        Section("Linear Integration") {
            Toggle("Enable Linear sync", isOn: $linearEnabled)

            if linearEnabled {
                SecureField("API Token", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onChange(of: token) { saveToken() }

                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .controlSize(.small)
                    connectionStatusView(testStatus)
                    Spacer()
                    if !token.isEmpty {
                        Button("Clear Token") {
                            token = ""
                            try? KeychainHelper.delete(account: Self.keychainAccount)
                            testStatus = .idle
                        }
                        .controlSize(.small)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .onAppear {
            token = KeychainHelper.loadToken(for: Self.keychainAccount) ?? ""
        }
    }

    private func saveToken() {
        guard !token.isEmpty else { return }
        try? KeychainHelper.saveToken(token, for: Self.keychainAccount)
    }

    private func testConnection() {
        guard !token.isEmpty else {
            testStatus = .failed("No token")
            return
        }
        testStatus = .testing
        Task {
            do {
                var request = URLRequest(url: URL(string: "https://api.linear.app/graphql")!)
                request.httpMethod = "POST"
                request.setValue(token, forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = #"{"query":"{ viewer { id } }"}"#.data(using: .utf8)
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    await MainActor.run { testStatus = .success }
                } else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let body = String(data: data, encoding: .utf8) ?? ""
                    await MainActor.run { testStatus = .failed("HTTP \(code): \(body)") }
                }
            } catch {
                await MainActor.run { testStatus = .failed(error.localizedDescription) }
            }
        }
    }
}

// MARK: - Pylon Settings

struct PylonSettingsSection: View {
    @AppStorage("pylon.enabled") private var pylonEnabled: Bool = false
    @AppStorage("pylon.email") private var pylonEmail: String = ""
    @State private var token: String = ""
    @State private var testStatus: ConnectionTestStatus = .idle

    private static let keychainAccount = "pylon-api-token"

    var body: some View {
        Section("Pylon Integration") {
            Toggle("Enable Pylon sync", isOn: $pylonEnabled)

            if pylonEnabled {
                TextField("Your email", text: $pylonEmail)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                SecureField("API Token", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onChange(of: token) { saveToken() }

                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .controlSize(.small)
                    connectionStatusView(testStatus)
                    Spacer()
                    if !token.isEmpty {
                        Button("Clear Token") {
                            token = ""
                            try? KeychainHelper.delete(account: Self.keychainAccount)
                            testStatus = .idle
                        }
                        .controlSize(.small)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .onAppear {
            token = KeychainHelper.loadToken(for: Self.keychainAccount) ?? ""
        }
    }

    private func saveToken() {
        guard !token.isEmpty else { return }
        try? KeychainHelper.saveToken(token, for: Self.keychainAccount)
    }

    private func testConnection() {
        guard !token.isEmpty else {
            testStatus = .failed("No token")
            return
        }
        testStatus = .testing
        Task {
            do {
                // Pylon /issues requires start_time & end_time; use a 1-day window with limit=1
                let now = ISO8601DateFormatter().string(from: Date())
                let yesterday = ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -86400))
                var components = URLComponents(string: "https://api.usepylon.com/issues")!
                components.queryItems = [
                    URLQueryItem(name: "start_time", value: yesterday),
                    URLQueryItem(name: "end_time", value: now),
                    URLQueryItem(name: "limit", value: "1"),
                ]
                var request = URLRequest(url: components.url!)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    await MainActor.run { testStatus = .success }
                } else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let body = String(data: data, encoding: .utf8) ?? ""
                    await MainActor.run { testStatus = .failed("HTTP \(code): \(body)") }
                }
            } catch {
                await MainActor.run { testStatus = .failed(error.localizedDescription) }
            }
        }
    }
}

// MARK: - Sync Schedule

struct SyncScheduleSection: View {
    var syncService: APISyncService
    @AppStorage("api.syncInterval") private var syncIntervalMinutes: Double = 5
    @State private var showLog = false

    private let syncIntervalOptions: [Double] = [1, 2, 5, 10, 15, 30]

    var body: some View {
        Section("API Sync Schedule") {
            Picker("Sync interval", selection: $syncIntervalMinutes) {
                ForEach(syncIntervalOptions, id: \.self) { min in
                    Text("\(Int(min)) min").tag(min)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Button("Sync Now") {
                    NotificationCenter.default.post(name: .apiSyncRequested, object: nil)
                }
                .controlSize(.small)
                .disabled(syncService.isSyncing)

                if syncService.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Button(showLog ? "Hide Log" : "Show Log") {
                    showLog.toggle()
                }
                .controlSize(.small)
            }

            if let error = syncService.lastError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            if showLog {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(syncService.syncLog.enumerated()), id: \.offset) { idx, entry in
                                Text(entry)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(entry.contains("ERROR") || entry.contains("failed") ? .red : .secondary)
                                    .textSelection(.enabled)
                                    .id(idx)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                    .frame(height: 120)
                    .background(.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onChange(of: syncService.syncLog.count) {
                        if let last = syncService.syncLog.indices.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shared

enum ConnectionTestStatus {
    case idle
    case testing
    case success
    case failed(String)
}

@ViewBuilder
func connectionStatusView(_ status: ConnectionTestStatus) -> some View {
    switch status {
    case .idle:
        EmptyView()
    case .testing:
        ProgressView()
            .controlSize(.small)
    case .success:
        Label("Connected", systemImage: "checkmark.circle.fill")
            .font(.system(size: 11))
            .foregroundStyle(.green)
    case .failed(let msg):
        Label(msg, systemImage: "xmark.circle.fill")
            .font(.system(size: 11))
            .foregroundStyle(.red)
            .textSelection(.enabled)
    }
}

extension Notification.Name {
    static let apiSyncRequested = Notification.Name("apiSyncRequested")
    static let apiSyncCompleted = Notification.Name("apiSyncCompleted")
}
