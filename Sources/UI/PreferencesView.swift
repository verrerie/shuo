import SwiftUI
import AppKit
import AVFoundation

struct PreferencesView: View {
    @Binding var config: Config

    let micGranted: Bool
    let accessibilityGranted: Bool
    let inputMonitoringGranted: Bool

    let onRequestMic: () -> Void
    let onOpenAccessibility: () -> Void
    let onOpenInputMonitoring: () -> Void
    let onSave: () -> Void

    var body: some View {
        Form {
            Section("OpenAI") {
                SecureField("API Key", text: $config.openaiApiKey)
                    .textFieldStyle(.roundedBorder)
            }
            Section("Language") {
                Picker("Default language", selection: $config.defaultLanguage) {
                    ForEach(Language.allCases, id: \.self) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Hotkey") {
                Picker("Modifier", selection: $config.hotkeyModifier) {
                    Text("Left Option").tag(HotkeyModifier.leftOption)
                    Text("Right Option").tag(HotkeyModifier.rightOption)
                }
                Text("Double-tap to start, single tap to stop.").font(.caption).foregroundColor(.secondary)
            }
            Section("Cost") {
                Stepper("Daily cap: \(config.dailyCapMinutes) min", value: $config.dailyCapMinutes, in: 5...600, step: 5)
            }
            Section("Permissions") {
                permissionRow(label: "Microphone", granted: micGranted, action: onRequestMic, actionTitle: "Grant")
                permissionRow(label: "Accessibility", granted: accessibilityGranted, action: onOpenAccessibility, actionTitle: "Open Settings")
                permissionRow(label: "Input Monitoring", granted: inputMonitoringGranted, action: onOpenInputMonitoring, actionTitle: "Open Settings")
            }
            HStack {
                Spacer()
                Button("Save", action: onSave).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    @ViewBuilder
    private func permissionRow(label: String, granted: Bool, action: @escaping () -> Void, actionTitle: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(granted ? "Granted" : "Not granted")
                .foregroundColor(granted ? .green : .red)
            if !granted { Button(actionTitle, action: action) }
        }
    }
}
