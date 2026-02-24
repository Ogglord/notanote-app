import Foundation

/// GraphQL client for the Linear API.
public final class LinearAPIClient: Sendable {
    private let apiKey: String
    private let session: URLSession
    private static let endpoint = URL(string: "https://api.linear.app/graphql")!

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Fetch issues assigned to the authenticated user that are still active.
    public func fetchMyIssues() async throws -> [LinearIssue] {
        let query = """
        {
          viewer {
            assignedIssues(
              filter: { state: { type: { nin: ["completed", "canceled"] } } }
              first: 100
              orderBy: updatedAt
            ) {
              nodes {
                id
                identifier
                title
                url
                priority
                state { name type }
              }
            }
          }
        }
        """

        let body: [String: Any] = ["query": query]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

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

        let decoded: LinearGraphQLResponse
        do {
            decoded = try JSONDecoder().decode(LinearGraphQLResponse.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error)
        }

        if let errors = decoded.errors, !errors.isEmpty {
            throw APIError.graphQLErrors(errors.map(\.message))
        }

        return decoded.data?.viewer.assignedIssues.nodes ?? []
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
}
