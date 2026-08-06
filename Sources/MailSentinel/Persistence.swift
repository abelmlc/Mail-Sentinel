import Foundation

final class FeedbackStore {
    static let shared = FeedbackStore()

    private let lock = NSLock()
    private let storageURL: URL
    private var state: PersistentState

    init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            self.storageURL = support
                .appendingPathComponent("Mail Sentinel", isDirectory: true)
                .appendingPathComponent("state.json")
        }

        state = Self.load(from: self.storageURL)
    }

    func isProcessed(_ messageID: String) -> Bool {
        lock.withLock {
            state.processedMessages[messageID] != nil
        }
    }

    func markProcessed(_ messageIDs: [String], at date: Date = Date()) {
        lock.withLock {
            for messageID in messageIDs {
                state.processedMessages[messageID] = date
            }
            pruneLocked(referenceDate: date)
            saveLocked()
        }
    }

    func recordFeedback(
        messageID: String,
        sender: String,
        subject: String,
        useful: Bool,
        at date: Date = Date()
    ) {
        lock.withLock {
            state.feedback.removeAll { $0.messageID == messageID }
            state.feedback.append(
                FeedbackRecord(
                    messageID: messageID,
                    sender: sender,
                    subject: subject,
                    useful: useful,
                    recordedAt: date
                )
            )
            if state.feedback.count > 500 {
                state.feedback = Array(state.feedback.suffix(500))
            }
            saveLocked()
        }
    }

    func learningContext(limit: Int = 30) -> String {
        lock.withLock {
            let recent = state.feedback.suffix(limit)
            guard !recent.isEmpty else {
                return "Aucun retour utilisateur n'est encore disponible."
            }

            return recent.map { item in
                let label = item.useful ? "NOTIFICATION UTILE" : "NOTIFICATION INUTILE"
                return "- \(label) | expéditeur: \(item.sender) | objet: \(item.subject)"
            }.joined(separator: "\n")
        }
    }

    func snapshot() -> PersistentState {
        lock.withLock { state }
    }

    private static func load(from url: URL) -> PersistentState {
        guard let data = try? Data(contentsOf: url) else {
            return PersistentState()
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(PersistentState.self, from: data)) ?? PersistentState()
    }

    private func pruneLocked(referenceDate: Date) {
        let cutoff = referenceDate.addingTimeInterval(-60 * 60 * 24 * 90)
        state.processedMessages = state.processedMessages.filter { $0.value >= cutoff }
    }

    private func saveLocked() {
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // The next scan can still run. Persistence errors are intentionally non-fatal.
        }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
