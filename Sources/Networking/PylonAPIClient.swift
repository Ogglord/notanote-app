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

    /// Fetch active issues assigned to the authenticated user.
    public func fetchMyIssues() async throws -> [PylonIssue] {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent("/issues"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "states", value: "new,waiting_on_you,waiting_on_customer,on_hold"),
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
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoded: PylonSearchResponse
        do {
            decoded = try JSONDecoder().decode(PylonSearchResponse.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error)
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
