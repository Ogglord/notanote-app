import Foundation

// MARK: - Linear GraphQL Response Structures

public struct LinearGraphQLResponse: Codable {
    public let data: LinearData?
    public let errors: [LinearGraphQLError]?

    public struct LinearData: Codable {
        public let viewer: LinearViewer
    }

    public struct LinearViewer: Codable {
        public let assignedIssues: LinearIssueConnection
    }

    public struct LinearIssueConnection: Codable {
        public let nodes: [LinearIssue]
    }
}

public struct LinearGraphQLError: Codable {
    public let message: String
}

public struct LinearIssue: Codable, Identifiable {
    public let id: String
    public let identifier: String
    public let title: String
    public let url: String
    public let priority: Int
    public let state: LinearState

    public struct LinearState: Codable {
        public let name: String
        public let type: String
    }
}

// MARK: - Pylon REST Response Structures

public struct PylonMeResponse: Codable {
    public let id: String
    public let name: String
    public let email: String
}

public struct PylonSearchResponse: Codable {
    public let data: [PylonIssue]?
    public let request_id: String?
}

public struct PylonIssue: Codable, Identifiable {
    public let id: String
    public let number: Int
    public let title: String
    public let state: String
    public let source: String?
    public let type: String?
    public let account_id: String?
    public let assignee_id: String?
    public let assignee: PylonRef?

    /// Resolved assignee ID: prefer flat field, fall back to nested object
    public var resolvedAssigneeId: String? {
        assignee_id ?? assignee?.id
    }

    public struct PylonRef: Codable {
        public let id: String
    }
}

// MARK: - Generic Digest Item

/// A unified representation of an item to be written to a digest markdown file.
public struct DigestItem {
    public let text: String
    public let sourceId: String
    public let url: String?
    public let identifier: String?
    public let priority: String?
    public let status: String?

    public init(
        text: String,
        sourceId: String,
        url: String? = nil,
        identifier: String? = nil,
        priority: String? = nil,
        status: String? = nil
    ) {
        self.text = text
        self.sourceId = sourceId
        self.url = url
        self.identifier = identifier
        self.priority = priority
        self.status = status
    }
}

// MARK: - Linear Notifications (Inbox) Response Structures

public struct LinearNotificationsResponse: Codable {
    public let data: NotificationsData?
    public let errors: [LinearGraphQLError]?

    public struct NotificationsData: Codable {
        public let notifications: NotificationConnection
    }

    public struct NotificationConnection: Codable {
        public let nodes: [LinearNotification]
    }
}

public struct LinearNotification: Codable, Identifiable {
    public let id: String
    public let type: String
    public let readAt: String?
    public let createdAt: String
    public let issue: NotificationIssue?

    public struct NotificationIssue: Codable {
        public let id: String
        public let identifier: String
        public let title: String
        public let url: String
    }
}

// MARK: - API Errors

public enum APIError: LocalizedError {
    case unauthorized
    case rateLimited
    case serverError(statusCode: Int, body: String? = nil)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)
    case noToken(service: String)
    case graphQLErrors([String])

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid or expired API token (401 Unauthorized)"
        case .rateLimited:
            return "Rate limited by API (429). Try again later."
        case .serverError(let code, let body):
            if let body, !body.isEmpty {
                return "HTTP \(code): \(body)"
            }
            return "Server error (HTTP \(code))"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        case .decodingError(let err):
            return "Failed to decode response: \(err.localizedDescription)"
        case .noToken(let service):
            return "No API token configured for \(service). Add one in Settings."
        case .graphQLErrors(let messages):
            return "GraphQL errors: \(messages.joined(separator: "; "))"
        }
    }
}
