import Foundation

/// REST client for the Pylon API.
public final class PylonAPIClient: Sendable {
    private let apiKey: String
    private let session: URLSession
    private static let baseURL = URL(string: "https://api.usepylon.com")!

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Fetch the authenticated user's ID by listing all users and matching by email.
    public func fetchCurrentUserId(email: String) async throws -> String {
        let url = Self.baseURL.appendingPathComponent("/users")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw APIError.unauthorized
        default:
            let body = String(data: data, encoding: .utf8)
            throw APIError.serverError(statusCode: httpResponse.statusCode, body: body)
        }

        struct UserResponse: Codable {
            let id: String
            let email: String?
            let emails: [String]?
        }
        struct UsersListResponse: Codable { let data: [UserResponse]? }

        guard let result = try? JSONDecoder().decode(UsersListResponse.self, from: data),
              let users = result.data else {
            let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
            throw APIError.decodingError(underlying: NSError(
                domain: "PylonDecode",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Failed to decode users list. Response: \(preview)"]
            ))
        }

        let lowered = email.lowercased()
        if let match = users.first(where: {
            $0.email?.lowercased() == lowered ||
            ($0.emails?.contains(where: { $0.lowercased() == lowered }) ?? false)
        }) {
            return match.id
        }

        throw APIError.decodingError(underlying: NSError(
            domain: "PylonDecode",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "No user found matching email \(email). Found \(users.count) users."]
        ))
    }

    /// Fetch all recent issues (last 90 days). Filtering by state/assignee is done client-side.
    public func fetchAllRecentIssues() async throws -> [PylonIssue] {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent("/issues"), resolvingAgainstBaseURL: false)!
        let fmt = ISO8601DateFormatter()
        components.queryItems = [
            URLQueryItem(name: "start_time", value: fmt.string(from: Date(timeIntervalSinceNow: -30 * 86400))),
            URLQueryItem(name: "end_time", value: fmt.string(from: Date())),
            URLQueryItem(name: "limit", value: "250"),
        ]

        guard let url = components.url else {
            throw APIError.networkError(underlying: URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw APIError.unauthorized
        case 429:
            throw APIError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8)
            throw APIError.serverError(statusCode: httpResponse.statusCode, body: body)
        }

        let decoded: PylonSearchResponse
        do {
            decoded = try JSONDecoder().decode(PylonSearchResponse.self, from: data)
        } catch {
            let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
            throw APIError.decodingError(underlying: NSError(
                domain: "PylonDecode",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "\(error.localizedDescription)\nResponse: \(preview)"]
            ))
        }

        return decoded.data ?? []
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
}
