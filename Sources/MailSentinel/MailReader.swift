import AppKit
import Foundation

enum MailReaderError: LocalizedError {
    case scriptCreation
    case scriptExecution(String)
    case invalidResult

    var errorDescription: String? {
        switch self {
        case .scriptCreation:
            return "Impossible de préparer l'accès à Apple Mail."
        case .scriptExecution(let details):
            return "Apple Mail a refusé ou interrompu la lecture : \(details)"
        case .invalidResult:
            return "Apple Mail a renvoyé un résultat illisible."
        }
    }
}

enum MailReader {
    static func fetchMessages(
        since date: Date,
        unreadOnly: Bool = false,
        limit: Int = 500
    ) throws -> [MailMessage] {
        let elapsed = Int(Date().timeIntervalSince(date))
        let lookbackSeconds = min(max(elapsed + 600, 600), 60 * 60 * 24 * 365)
        let safeLimit = min(max(limit, 1), 5_000)
        let unreadOnlyValue = unreadOnly ? "true" : "false"

        let source = """
        set cutoffDate to (current date) - \(lookbackSeconds)
        set outputRecords to {}
        set selectedCount to 0
        set unreadOnlyFlag to \(unreadOnlyValue)

        tell application "Mail"
            set candidateMessages to every message of inbox whose date received is greater than or equal to cutoffDate
            repeat with currentMessage in candidateMessages
                try
                    set readValue to read status of currentMessage
                    if (unreadOnlyFlag is false) or (readValue is false) then
                        set localID to id of currentMessage as string
                        set internetID to message id of currentMessage as string
                        if internetID is "" then set internetID to "mail-local-" & localID
                        set senderText to sender of currentMessage as string
                        set subjectText to subject of currentMessage as string
                        set receivedText to date received of currentMessage as string
                        set repliedValue to was replied to of currentMessage
                        set bodyText to ""
                        try
                            set bodyText to content of currentMessage as string
                            if (length of bodyText) > 1800 then set bodyText to text 1 thru 1800 of bodyText
                        end try
                        set end of outputRecords to {internetID, senderText, subjectText, receivedText, bodyText, readValue, repliedValue}
                        set selectedCount to selectedCount + 1
                        if selectedCount is greater than or equal to \(safeLimit) then exit repeat
                    end if
                end try
            end repeat
        end tell

        return outputRecords
        """

        guard let script = NSAppleScript(source: source) else {
            throw MailReaderError.scriptCreation
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let details = errorInfo[NSAppleScript.errorMessage] as? String
                ?? errorInfo.description
            throw MailReaderError.scriptExecution(details)
        }

        guard result.numberOfItems >= 0 else {
            throw MailReaderError.invalidResult
        }

        var messages: [MailMessage] = []
        if result.numberOfItems == 0 {
            return messages
        }

        for index in 1...result.numberOfItems {
            guard let row = result.atIndex(index), row.numberOfItems >= 7,
                  let messageID = row.atIndex(1)?.stringValue,
                  !messageID.isEmpty else {
                continue
            }

            messages.append(
                MailMessage(
                    messageID: messageID,
                    sender: row.atIndex(2)?.stringValue ?? "Expéditeur inconnu",
                    subject: row.atIndex(3)?.stringValue ?? "Sans objet",
                    receivedDescription: row.atIndex(4)?.stringValue ?? "",
                    contentPreview: sanitize(row.atIndex(5)?.stringValue ?? ""),
                    isRead: row.atIndex(6)?.booleanValue ?? false,
                    wasRepliedTo: row.atIndex(7)?.booleanValue ?? false
                )
            )
        }

        return messages
    }

    static func openMessage(messageID: String) {
        let escapedID = escapeAppleScriptString(messageID)
        let source = """
        tell application "Mail"
            activate
            try
                set matchingMessages to every message of inbox whose message id is "\(escapedID)"
                if (count of matchingMessages) > 0 then open item 1 of matchingMessages
            end try
        end tell
        """
        var errorInfo: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
    }

    static func escapeAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{0000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
