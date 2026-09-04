import SwiftUI

struct SettingsView: View {
    @StateObject private var login = LoginItemManager()

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { login.isEnabled },
                set: { login.setEnabled($0) }
            ))
            Text("Usage refreshes every 5 minutes from local Codex session events.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let error = login.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
