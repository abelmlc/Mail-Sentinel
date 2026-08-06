import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var status = "Prêt pour une première analyse"
    @Published private(set) var isScanning = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var lastSummary: ScanSummary?
    @Published private(set) var history: [AnalysisRecord] = []

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

    @Published var historicalLookbackDays: Int {
        didSet {
            historicalLookbackDays = max(7, min(historicalLookbackDays, 365))
            defaults.set(historicalLookbackDays, forKey: Keys.historicalLookbackDays)
        }
    }

    @Published var historicalUnreadOnly: Bool {
        didSet {
            defaults.set(historicalUnreadOnly, forKey: Keys.historicalUnreadOnly)
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
        static let historicalLookbackDays = "historicalLookbackDays"
        static let historicalUnreadOnly = "historicalUnreadOnly"
    }

    init() {
        automaticScanEnabled = defaults.object(forKey: Keys.automaticScan) as? Bool ?? true
        intervalHours = defaults.object(forKey: Keys.intervalHours) as? Int ?? 1
        notificationThreshold = defaults.object(forKey: Keys.threshold) as? Int ?? 65
        historicalLookbackDays = defaults.object(forKey: Keys.historicalLookbackDays) as? Int ?? 30
        historicalUnreadOnly = defaults.object(forKey: Keys.historicalUnreadOnly) as? Bool ?? true
        lastScanDate = defaults.object(forKey: Keys.lastScan) as? Date
        history = store.snapshot().analysisHistory.sorted { $0.analyzedAt > $1.analyzedAt }
        configureTimer()

        NotificationCenter.default.addObserver(
            forName: .mailSentinelFeedbackChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshHistory() }
        }
    }

    func scanNow() {
        guard !isScanning else { return }
        let cutoff = lastScanDate ?? Date().addingTimeInterval(-60 * 60 * 24)
        Task {
            await performScan(
                cutoff: cutoff,
                unreadOnly: false,
                fetchLimit: 500,
                analysisLimit: 500,
                isHistorical: false
            )
        }
    }

    func scanHistory() {
        guard !isScanning else { return }
        let cutoff = Date().addingTimeInterval(-TimeInterval(historicalLookbackDays * 24 * 60 * 60))
        Task {
            await performScan(
                cutoff: cutoff,
                unreadOnly: historicalUnreadOnly,
                fetchLimit: 1_500,
                analysisLimit: 250,
                isHistorical: true
            )
        }
    }

    func refreshHistory() {
        history = store.snapshot().analysisHistory.sorted { $0.analyzedAt > $1.analyzedAt }
    }

    private func performScan(
        cutoff: Date,
        unreadOnly: Bool,
        fetchLimit: Int,
        analysisLimit: Int,
        isHistorical: Bool
    ) async {
        isScanning = true
        status = isHistorical
            ? "Recherche des anciens messages dans Mail…"
            : "Lecture des nouveaux messages dans Mail…"
        defer { isScanning = false }

        let scanStartedAt = Date()

        do {
            let messages = try await Task.detached(priority: .userInitiated) {
                try MailReader.fetchMessages(
                    since: cutoff,
                    unreadOnly: unreadOnly,
                    limit: fetchLimit
                )
            }.value

            let allUnseen = messages.filter { store.needsClassification($0.messageID) }
            let unseen = Array(allUnseen.prefix(analysisLimit))
            let remainingCount = max(0, allUnseen.count - unseen.count)
            if unseen.isEmpty {
                finishScan(
                    at: scanStartedAt,
                    summary: ScanSummary(checked: messages.count, newMessages: 0, notifications: 0),
                    status: isHistorical
                        ? "Aucun ancien message restant à analyser"
                        : "Aucun nouveau message à analyser",
                    updateRegularScanDate: !isHistorical
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
            var historyRecords: [AnalysisRecord] = []
            for result in results {
                guard let message = messagesByID[result.messageID] else { continue }
                let shouldSendNotification = result.warrantsNotification(
                    threshold: notificationThreshold
                )
                if shouldSendNotification {
                    await NotificationManager.shared.notify(
                        message: message,
                        classification: result
                    )
                    notificationCount += 1
                }

                historyRecords.append(
                    AnalysisRecord(
                        messageID: message.messageID,
                        sender: message.sender,
                        subject: message.subject,
                        receivedDescription: message.receivedDescription,
                        analyzedAt: scanStartedAt,
                        importance: result.normalizedImportance,
                        notificationSent: shouldSendNotification,
                        requiresReply: result.requiresReply,
                        reason: result.reason,
                        userFeedback: nil
                    )
                )
            }

            store.recordAnalyses(historyRecords, processedAt: scanStartedAt)
            refreshHistory()
            let summary = ScanSummary(
                checked: messages.count,
                newMessages: unseen.count,
                notifications: notificationCount
            )
            var finalStatus = notificationCount == 0
                ? "Analyse terminée : rien d'urgent"
                : "\(notificationCount) message(s) important(s) signalé(s)"
            if remainingCount > 0 {
                finalStatus += " • \(remainingCount) restant(s), relance l'analyse historique"
            }
            finishScan(
                at: scanStartedAt,
                summary: summary,
                status: finalStatus,
                updateRegularScanDate: !isHistorical
            )
        } catch {
            status = error.localizedDescription
        }
    }

    private func finishScan(
        at date: Date,
        summary: ScanSummary,
        status: String,
        updateRegularScanDate: Bool
    ) {
        if updateRegularScanDate {
            lastScanDate = date
            defaults.set(date, forKey: Keys.lastScan)
        }
        lastSummary = summary
        self.status = status
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
