import Foundation

private enum SelfTestError: Error {
    case failed(String)
}

private func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw SelfTestError.failed(message) }
}

do {
    let data = Data(
        """
        {
          "message_id": "abc@example.test",
          "importance": 82,
          "should_notify": true,
          "requires_reply": true,
          "reason": "Demande directe"
        }
        """.utf8
    )
    let result = try JSONDecoder().decode(ClassificationResult.self, from: data)
    try check(result.messageID == "abc@example.test", "Décodage de message_id")
    try check(result.importance == 82, "Décodage de l'importance")
    try check(result.shouldNotify, "Décodage de should_notify")
    try check(result.requiresReply, "Décodage de requires_reply")

    let inconsistentModelResult = ClassificationResult(
        messageID: "urgent-1",
        importance: 1,
        shouldNotify: true,
        requiresReply: true,
        reason: "Échéance proche"
    )
    try check(
        inconsistentModelResult.normalizedImportance == 65,
        "Normalisation d'une décision explicite incohérente"
    )
    try check(
        inconsistentModelResult.warrantsNotification(threshold: 65),
        "Protection des emails urgents malgré un score incohérent"
    )

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = FeedbackStore(storageURL: url)
    store.recordAnalyses(
        [
            AnalysisRecord(
                messageID: "message-1",
                sender: "Alice <alice@example.test>",
                subject: "Réunion vendredi",
                receivedDescription: "vendredi",
                analyzedAt: Date(),
                importance: 82,
                notificationSent: true,
                requiresReply: true,
                reason: "Demande directe",
                userFeedback: nil
            )
        ]
    )
    store.recordFeedback(
        messageID: "message-1",
        sender: "Alice <alice@example.test>",
        subject: "Réunion vendredi",
        useful: true
    )

    let reloaded = FeedbackStore(storageURL: url)
    try check(reloaded.isProcessed("message-1"), "Persistance des messages traités")
    try check(reloaded.snapshot().feedback.count == 1, "Persistance du retour")
    try check(reloaded.snapshot().feedback.first?.useful == true, "Valeur du retour")
    try check(reloaded.snapshot().analysisHistory.count == 1, "Persistance de l'historique")
    try check(
        reloaded.snapshot().analysisHistory.first?.userFeedback == true,
        "Association du retour à l'historique"
    )
    try check(
        reloaded.needsClassification("message-1") == false,
        "Un message historisé ne doit pas être reclassé"
    )

    let legacyData = Data(
        """
        {"processedMessages": {}, "feedback": []}
        """.utf8
    )
    let legacyState = try JSONDecoder().decode(PersistentState.self, from: legacyData)
    try check(legacyState.analysisHistory.isEmpty, "Migration de l'ancien état sans historique")

    let escaped = MailReader.escapeAppleScriptString("id\\with\"quotes")
    try check(escaped == "id\\\\with\\\"quotes", "Échappement AppleScript")

    print("SELF_TEST_OK")
} catch {
    fputs("SELF_TEST_FAILED: \(error)\n", stderr)
    exit(1)
}
