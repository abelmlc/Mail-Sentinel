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

        Toggle("Analyse automatique", isOn: $model.automaticScanEnabled)

        SettingsLink {
            Label("Réglages…", systemImage: "gearshape")
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
        Form {
            Section("Analyse") {
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

            Section("Confidentialité") {
                Text("Modèle : qwen3:8b via Ollama local")
                Text("Le corps des messages n'est pas enregistré. Seuls l'identifiant, l'expéditeur, l'objet et ton retour utile/inutile sont conservés localement.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 330)
        .padding()
    }
}
