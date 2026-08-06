// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MailSentinel",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MailSentinel", targets: ["MailSentinel"])
    ],
    targets: [
        .executableTarget(name: "MailSentinel")
    ],
    swiftLanguageModes: [.v5]
)
