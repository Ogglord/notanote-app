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
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = #"{"query":"{ viewer { id } }"}"#.data(using: .utf8)
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    await MainActor.run { testStatus = .success }
                } else {
                    await MainActor.run { testStatus = .failed("HTTP error") }
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
    @State private var token: String = ""
    @State private var testStatus: ConnectionTestStatus = .idle

    private static let keychainAccount = "pylon-api-token"

    var body: some View {
        Section("Pylon Integration") {
            Toggle("Enable Pylon sync", isOn: $pylonEnabled)

            if pylonEnabled {
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
                var request = URLRequest(url: URL(string: "https://api.usepylon.com/issues?limit=1")!)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    await MainActor.run { testStatus = .success }
                } else {
                    await MainActor.run { testStatus = .failed("HTTP error") }
                }
            } catch {
                await MainActor.run { testStatus = .failed(error.localizedDescription) }
            }
        }
    }
}

// MARK: - Sync Schedule

struct SyncScheduleSection: View {
    @AppStorage("api.syncInterval") private var syncIntervalMinutes: Double = 5
    @AppStorage("api.lastSyncTime") private var lastSyncTime: Double = 0
    @AppStorage("api.lastSyncError") private var lastSyncError: String = ""

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

                Spacer()

                if lastSyncTime > 0 {
                    let date = Date(timeIntervalSince1970: lastSyncTime)
                    Text("Last sync: \(date.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            if !lastSyncError.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 10))
                    Text(lastSyncError)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .lineLimit(2)
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
    }
}

extension Notification.Name {
    static let apiSyncRequested = Notification.Name("apiSyncRequested")
}
