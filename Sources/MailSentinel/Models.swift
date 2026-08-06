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

struct AnalysisRecord: Codable, Identifiable, Equatable {
    let messageID: String
    let sender: String
    let subject: String
    let receivedDescription: String
    let analyzedAt: Date
    let importance: Int
    let notificationSent: Bool
    let requiresReply: Bool
    let reason: String
    var userFeedback: Bool?

    var id: String { messageID }
}

struct PersistentState: Codable, Equatable {
    var processedMessages: [String: Date] = [:]
    var feedback: [FeedbackRecord] = []
    var analysisHistory: [AnalysisRecord] = []

    enum CodingKeys: String, CodingKey {
        case processedMessages
        case feedback
        case analysisHistory
    }

    init(
        processedMessages: [String: Date] = [:],
        feedback: [FeedbackRecord] = [],
        analysisHistory: [AnalysisRecord] = []
    ) {
        self.processedMessages = processedMessages
        self.feedback = feedback
        self.analysisHistory = analysisHistory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        processedMessages = try container.decodeIfPresent(
            [String: Date].self,
            forKey: .processedMessages
        ) ?? [:]
        feedback = try container.decodeIfPresent(
            [FeedbackRecord].self,
            forKey: .feedback
        ) ?? []
        analysisHistory = try container.decodeIfPresent(
            [AnalysisRecord].self,
            forKey: .analysisHistory
        ) ?? []
    }
}

struct ScanSummary: Equatable {
    let checked: Int
    let newMessages: Int
    let notifications: Int
}
