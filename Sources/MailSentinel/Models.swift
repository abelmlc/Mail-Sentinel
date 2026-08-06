import Foundation

struct MailMessage: Codable, Identifiable, Equatable {
    let messageID: String
    let sender: String
    let subject: String
    let receivedDescription: String
    let contentPreview: String
    let isRead: Bool
    let wasRepliedTo: Bool

    var id: String { messageID }
}

struct ClassificationResult: Codable, Equatable {
    let messageID: String
    let importance: Int
    let shouldNotify: Bool
    let requiresReply: Bool
    let reason: String

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case importance
        case shouldNotify = "should_notify"
        case requiresReply = "requires_reply"
        case reason
    }

    var normalizedImportance: Int {
        let bounded = min(100, max(0, importance))
        return shouldNotify ? max(65, bounded) : bounded
    }

    func warrantsNotification(threshold: Int) -> Bool {
        normalizedImportance >= threshold
    }
}

struct FeedbackRecord: Codable, Equatable {
    let messageID: String
    let sender: String
    let subject: String
    let useful: Bool
    let recordedAt: Date
}

struct PersistentState: Codable, Equatable {
    var processedMessages: [String: Date] = [:]
    var feedback: [FeedbackRecord] = []
}

struct ScanSummary: Equatable {
    let checked: Int
    let newMessages: Int
    let notifications: Int
}
