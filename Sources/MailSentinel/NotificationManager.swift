import AppKit
import Foundation
import UserNotifications

extension Notification.Name {
    static let mailSentinelFeedbackChanged = Notification.Name("mailSentinelFeedbackChanged")
}

enum NotificationActionID {
    static let useful = "MAIL_SENTINEL_USEFUL"
    static let notUseful = "MAIL_SENTINEL_NOT_USEFUL"
    static let category = "MAIL_SENTINEL_IMPORTANT_EMAIL"
}

final class NotificationManager {
    static let shared = NotificationManager()

    func configure() {
        let useful = UNNotificationAction(
            identifier: NotificationActionID.useful,
            title: "Utile",
            options: []
        )
        let notUseful = UNNotificationAction(
            identifier: NotificationActionID.notUseful,
            title: "Pas utile",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: NotificationActionID.category,
            actions: [useful, notUseful],
            intentIdentifiers: [],
            options: []
        )
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notify(message: MailMessage, classification: ClassificationResult) async {
        let content = UNMutableNotificationContent()
        content.title = message.subject
        content.subtitle = message.sender
        content.body = classification.requiresReply
            ? "Réponse probablement attendue • \(classification.reason)"
            : classification.reason
        content.sound = .default
        content.categoryIdentifier = NotificationActionID.category
        content.userInfo = [
            "messageID": message.messageID,
            "sender": message.sender,
            "subject": message.subject
        ]

        let request = UNNotificationRequest(
            identifier: "mail-sentinel-\(message.messageID)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.configure()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let info = response.notification.request.content.userInfo
        guard let messageID = info["messageID"] as? String else { return }
        let sender = info["sender"] as? String ?? ""
        let subject = info["subject"] as? String ?? ""

        switch response.actionIdentifier {
        case NotificationActionID.useful:
            FeedbackStore.shared.recordFeedback(
                messageID: messageID,
                sender: sender,
                subject: subject,
                useful: true
            )
        case NotificationActionID.notUseful:
            FeedbackStore.shared.recordFeedback(
                messageID: messageID,
                sender: sender,
                subject: subject,
                useful: false
            )
        case UNNotificationDefaultActionIdentifier:
            MailReader.openMessage(messageID: messageID)
        default:
            break
        }

        NotificationCenter.default.post(name: .mailSentinelFeedbackChanged, object: nil)
    }
}
