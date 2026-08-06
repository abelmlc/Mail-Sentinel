import AppKit
import SwiftUI

@main
struct MailSentinelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(model)
        } label: {
            Label(
                "Mail Sentinel",
                systemImage: model.isScanning ? "envelope.arrow.triangle.branch" : "envelope.badge.shield.half.filled"
            )
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

private struct MenuContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Text(model.status)
        if let lastScanDate = model.lastScanDate {
            Text("Dernière analyse : \(lastScanDate.formatted(date: .abbreviated, time: .shortened))")
        }

        Divider()

        Button {
            model.scanNow()
        } label: {
            Label(
                model.isScanning ? "Analyse en cours…" : "Analyser maintenant",
                systemImage: "envelope.badge.magnifyingglass"
            )
        }
        .disabled(model.isScanning)

        Button {
            model.scanHistory()
        } label: {
            Label(
                "Analyser les \(model.historicalLookbackDays) derniers jours",
                systemImage: "clock.arrow.circlepath"
            )
        }
        .disabled(model.isScanning)

        Toggle("Analyse automatique", isOn: $model.automaticScanEnabled)

        SettingsLink {
            Label("Réglages et historique…", systemImage: "list.bullet.rectangle")
        }

        Divider()

        Button("Quitter Mail Sentinel") {
            NSApplication.shared.terminate(nil)
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            Form {
                Section("Analyse automatique") {
                    Toggle("Analyser automatiquement", isOn: $model.automaticScanEnabled)
                    Stepper(
                        "Toutes les \(model.intervalHours) heure(s)",
                        value: $model.intervalHours,
                        in: 1...12
                    )
                    Slider(
                        value: Binding(
                            get: { Double(model.notificationThreshold) },
                            set: { model.notificationThreshold = Int($0.rounded()) }
                        ),
                        in: 40...95,
                        step: 5
                    ) {
                        Text("Seuil")
                    } minimumValueLabel: {
                        Text("Plus d'alertes")
                    } maximumValueLabel: {
                        Text("Très sélectif")
                    }
                    Text("Seuil actuel : \(model.notificationThreshold)/100")
                        .foregroundStyle(.secondary)
                }

                Section("Rattrapage des anciens messages") {
                    Stepper(
                        "Remonter sur \(model.historicalLookbackDays) jours",
                        value: $model.historicalLookbackDays,
                        in: 7...365,
                        step: 7
                    )
                    Toggle(
                        "Uniquement les messages non lus",
                        isOn: $model.historicalUnreadOnly
                    )
                    Button("Lancer l'analyse historique") {
                        model.scanHistory()
                    }
                    .disabled(model.isScanning)
                    Text("Un maximum de 250 messages est analysé par lancement pour limiter la charge. Relance l'opération si l'application indique qu'il en reste.")
                        .foregroundStyle(.secondary)
                }

                Section("Confidentialité") {
                    Text("Modèle : qwen3:8b via Ollama local")
                    Text("Le corps des messages n'est pas enregistré. L'historique local conserve l'expéditeur, l'objet, le score et la justification pendant 30 jours.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding()
            .tabItem {
                Label("Réglages", systemImage: "gearshape")
            }

            HistoryView()
                .environmentObject(model)
                .tabItem {
                    Label("Historique", systemImage: "clock")
                }
        }
        .frame(width: 760, height: 560)
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Historique des analyses")
                        .font(.title2.bold())
                    Text("\(model.history.count) décision(s) conservée(s) localement pendant 30 jours")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.refreshHistory()
                } label: {
                    Label("Actualiser", systemImage: "arrow.clockwise")
                }
            }

            if model.history.isEmpty {
                ContentUnavailableView(
                    "Aucune décision enregistrée",
                    systemImage: "tray",
                    description: Text("Lance une nouvelle analyse ou l'analyse historique.")
                )
            } else {
                List(model.history) { record in
                    HistoryRow(record: record)
                }
                .listStyle(.inset)
            }
        }
        .padding()
    }
}

private struct HistoryRow: View {
    let record: AnalysisRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(record.importance)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(scoreColor)
                .frame(width: 38, height: 38)
                .background(scoreColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(record.subject)
                    .font(.headline)
                    .lineLimit(2)
                Text(record.sender)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(record.reason)
                    .font(.callout)
                    .lineLimit(3)

                HStack(spacing: 10) {
                    Label(
                        record.notificationSent ? "Notification envoyée" : "Sans notification",
                        systemImage: record.notificationSent ? "bell.fill" : "bell.slash"
                    )
                    if record.requiresReply {
                        Label("Réponse attendue", systemImage: "arrowshape.turn.up.left")
                    }
                    if let feedback = record.userFeedback {
                        Label(
                            feedback ? "Utile" : "Pas utile",
                            systemImage: feedback ? "hand.thumbsup.fill" : "hand.thumbsdown.fill"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(record.analyzedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Ouvrir dans Mail") {
                    MailReader.openMessage(messageID: record.messageID)
                }
                .buttonStyle(.link)
            }
        }
        .padding(.vertical, 5)
    }

    private var scoreColor: Color {
        switch record.importance {
        case 80...:
            return .red
        case 65...:
            return .orange
        case 40...:
            return .yellow
        default:
            return .secondary
        }
    }
}
