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

    /// Fetch the authenticated user's ID.
    public func fetchMyUserId() async throws -> String {
        let url = Self.baseURL.appendingPathComponent("/me")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            throw APIError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, body: body)
        }
        let me = try JSONDecoder().decode(PylonMeResponse.self, from: data)
        return me.id
    }

    /// Fetch open issues assigned to the authenticated user (new + waiting on you).
    public func fetchMyIssues() async throws -> [PylonIssue] {
        let myId = try await fetchMyUserId()

        var components = URLComponents(url: Self.baseURL.appendingPathComponent("/issues"), resolvingAgainstBaseURL: false)!
        let now = ISO8601DateFormatter().string(from: Date())
        let thirtyDaysAgo = ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -30 * 86400))
        components.queryItems = [
            URLQueryItem(name: "start_time", value: thirtyDaysAgo),
            URLQueryItem(name: "end_time", value: now),
            URLQueryItem(name: "states", value: "new,waiting_on_you"),
            URLQueryItem(name: "assignee", value: myId),
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
