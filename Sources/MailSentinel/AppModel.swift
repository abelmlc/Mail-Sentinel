import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var status = "Prêt pour une première analyse"
    @Published private(set) var isScanning = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var lastSummary: ScanSummary?

    @Published var automaticScanEnabled: Bool {
        didSet {
            defaults.set(automaticScanEnabled, forKey: Keys.automaticScan)
            configureTimer()
        }
    }

    @Published var intervalHours: Int {
        didSet {
            intervalHours = max(1, min(intervalHours, 12))
            defaults.set(intervalHours, forKey: Keys.intervalHours)
            configureTimer()
        }
    }

    @Published var notificationThreshold: Int {
        didSet {
            notificationThreshold = max(40, min(notificationThreshold, 95))
            defaults.set(notificationThreshold, forKey: Keys.threshold)
        }
    }

    private let defaults = UserDefaults.standard
    private let store = FeedbackStore.shared
    private let classifier = OllamaClassifier()
    private var timer: Timer?

    private enum Keys {
        static let automaticScan = "automaticScanEnabled"
        static let intervalHours = "intervalHours"
        static let threshold = "notificationThreshold"
        static let lastScan = "lastScanDate"
    }

    init() {
        automaticScanEnabled = defaults.object(forKey: Keys.automaticScan) as? Bool ?? true
        intervalHours = defaults.object(forKey: Keys.intervalHours) as? Int ?? 1
        notificationThreshold = defaults.object(forKey: Keys.threshold) as? Int ?? 65
        lastScanDate = defaults.object(forKey: Keys.lastScan) as? Date
        configureTimer()
    }

    func scanNow() {
        guard !isScanning else { return }
        Task { await performScan() }
    }

    private func performScan() async {
        isScanning = true
        status = "Lecture des nouveaux messages dans Mail…"
        defer { isScanning = false }

        let scanStartedAt = Date()
        let cutoff = lastScanDate ?? scanStartedAt.addingTimeInterval(-60 * 60 * 24)

        do {
            let messages = try await Task.detached(priority: .userInitiated) {
                try MailReader.fetchMessages(since: cutoff)
            }.value

            let unseen = messages.filter { !store.isProcessed($0.messageID) }
            if unseen.isEmpty {
                finishScan(
                    at: scanStartedAt,
                    summary: ScanSummary(checked: messages.count, newMessages: 0, notifications: 0),
                    status: "Aucun nouveau message à analyser"
                )
                return
            }

            status = "Analyse locale de \(unseen.count) message(s) avec Qwen3 8B…"
            let results = try await classifier.classify(
                messages: unseen,
                learningContext: store.learningContext()
            )
            let messagesByID = Dictionary(uniqueKeysWithValues: unseen.map { ($0.messageID, $0) })

            var notificationCount = 0
            for result in results {
                guard let message = messagesByID[result.messageID] else { continue }
                if result.warrantsNotification(threshold: notificationThreshold) {
                    await NotificationManager.shared.notify(
                        message: message,
                        classification: result
                    )
                    notificationCount += 1
                }
            }

            store.markProcessed(unseen.map(\.messageID), at: scanStartedAt)
            let summary = ScanSummary(
                checked: messages.count,
                newMessages: unseen.count,
                notifications: notificationCount
            )
            let finalStatus = notificationCount == 0
                ? "Analyse terminée : rien d'urgent"
                : "\(notificationCount) message(s) important(s) signalé(s)"
            finishScan(at: scanStartedAt, summary: summary, status: finalStatus)
        } catch {
            status = error.localizedDescription
        }
    }

    private func finishScan(at date: Date, summary: ScanSummary, status: String) {
        lastScanDate = date
        lastSummary = summary
        self.status = status
        defaults.set(date, forKey: Keys.lastScan)
    }

    private func configureTimer() {
        timer?.invalidate()
        timer = nil
        guard automaticScanEnabled else { return }

        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(intervalHours * 60 * 60),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.scanNow() }
        }
    }
}
