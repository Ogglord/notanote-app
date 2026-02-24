import Foundation
import Security
import os.log

private let keychainLog = Logger(subsystem: "com.notanote", category: "Keychain")

private func logToFile(_ message: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    let line = "[\(ts)] \(message)\n"
    let path = "/tmp/notanote-keychain.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
    keychainLog.info("\(message)")
}

/// Secure token storage using the macOS Keychain.
/// All tokens are stored in a single keychain item (JSON dictionary)
/// so only one unlock prompt is needed.
public enum KeychainHelper {
    private static let service = "com.notanote.api-tokens"
    private static let account = "tokens"
    private static var cache: [String: String]?

    // MARK: - Public API

    public static func saveToken(_ token: String, for key: String) throws {
        logToFile("saveToken(for: \(key)) called")
        var tokens = loadAll()
        tokens[key] = token
        try saveAll(tokens)
        logToFile("saveToken(for: \(key)) done")
    }

    public static func loadToken(for key: String) -> String? {
        logToFile("loadToken(for: \(key)) called, cache=\(cache != nil ? "hit" : "miss")")
        let result = loadAll()[key]
        logToFile("loadToken(for: \(key)) -> \(result != nil ? "found" : "nil")")
        return result
    }

    public static func delete(account key: String) throws {
        logToFile("delete(account: \(key)) called")
        var tokens = loadAll()
        tokens.removeValue(forKey: key)
        try saveAll(tokens)
    }

    /// Load all tokens into memory. Call once at startup.
    public static func preloadTokens(accounts: [String]) {
        logToFile("preloadTokens called for \(accounts)")
        _ = loadAll()
        logToFile("preloadTokens done, cache keys: \(Array(cache?.keys ?? [:].keys))")
    }

    // MARK: - Private: single-item JSON storage

    private static func loadAll() -> [String: String] {
        if let cached = cache {
            logToFile("  loadAll() -> cache hit (\(cached.keys.count) keys)")
            return cached
        }

        logToFile("  loadAll() -> cache miss, calling SecItemCopyMatching for combined item")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        logToFile("  loadAll() SecItemCopyMatching status=\(status) (0=success, -25300=notFound)")

        var tokens: [String: String] = [:]
        if status == errSecSuccess, let data = result as? Data {
            tokens = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
            logToFile("  loadAll() decoded \(tokens.keys.count) keys from combined item")
        }

        // Migrate: check for old per-key items and merge them in
        let legacyKeys = ["linear-api-token", "pylon-api-token"]
        var migrated = false
        for key in legacyKeys where tokens[key] == nil {
            logToFile("  loadAll() checking legacy item: \(key)")
            if let old = loadLegacyItem(key: key) {
                tokens[key] = old
                deleteLegacyItem(key: key)
                migrated = true
                logToFile("  loadAll() migrated legacy item: \(key)")
            } else {
                logToFile("  loadAll() no legacy item for: \(key)")
            }
        }

        cache = tokens
        if migrated {
            logToFile("  loadAll() saving migrated tokens")
            try? saveAll(tokens)
        }
        return tokens
    }

    private static func saveAll(_ tokens: [String: String]) throws {
        logToFile("  saveAll() called with \(tokens.keys.count) keys")
        guard let data = try? JSONEncoder().encode(tokens) else {
            throw KeychainError.encodingError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        logToFile("  saveAll() calling SecItemUpdate")
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        logToFile("  saveAll() SecItemUpdate status=\(status)")

        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            logToFile("  saveAll() calling SecItemAdd (new item)")
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            logToFile("  saveAll() SecItemAdd status=\(addStatus)")
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }

        cache = tokens
    }

    // MARK: - Legacy migration (old per-key items)

    private static func loadLegacyItem(key: String) -> String? {
        logToFile("  loadLegacyItem(\(key)) calling SecItemCopyMatching")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        logToFile("  loadLegacyItem(\(key)) status=\(status)")
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteLegacyItem(key: String) {
        logToFile("  deleteLegacyItem(\(key)) calling SecItemDelete")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        logToFile("  deleteLegacyItem(\(key)) status=\(status)")
    }

    // MARK: - Errors

    public enum KeychainError: LocalizedError {
        case unhandledError(status: OSStatus)
        case encodingError

        public var errorDescription: String? {
            switch self {
            case .unhandledError(let status):
                return "Keychain error: \(status)"
            case .encodingError:
                return "Failed to encode token as UTF-8"
            }
        }
    }
}
