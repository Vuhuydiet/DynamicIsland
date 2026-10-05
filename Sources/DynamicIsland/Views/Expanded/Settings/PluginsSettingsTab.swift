import SwiftUI

// MARK: - Pane 8: Plugins & app integrations

// MARK: - Tab: Plugins & App Integrations

public struct PluginsSettingsTab: View {
    @ObservedObject private var pluginManager = PluginManager.shared
    @ObservedObject private var store = WebAppStore.shared
    @ObservedObject private var registry = WebAppRegistry.shared
    @ObservedObject private var appState = AppState.shared

    /// The shipped defaults, read once.
    ///
    /// Held as state rather than calling `loadFromBundle()` in `body`: that is a
    /// synchronous file read and JSON parse, and `body` runs on every re-render —
    /// every keystroke in the add-web-app field, every published change on any of
    /// the four observed objects above. A resource that cannot change while the app
    /// is running is read once and kept.
    @State private var presets: [WebAppDescriptor] = []

    /// Raw text from the add field, kept unparsed so the user's typing is never
    /// rewritten under them.
    @State private var draftURL: String = ""
    @State private var draftName: String = ""
    @State private var validationMessage: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Overview Card
            SettingsCard(
                title: "Web Apps",
                icon: "globe",
                iconColor: .cyan,
                subtitle: "Add any web app by address and use it inside the notch, with persistent login and live notifications."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "app.badge.checkmark.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.cyan)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("One Integration, Every Site")
                                .font(.system(size: 13, weight: .bold))
                            Text("Each web app is a descriptor driving the same plugin, tab, ear accessory, and settings UI.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.cyan.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            // 2. Add Web App
            SettingsCard(
                title: "Add Web App",
                icon: "plus.circle.fill",
                iconColor: .green,
                subtitle: "Paste a web address. A missing https:// is added for you."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("Web address (e.g. slack.com)", text: $draftURL)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addWebApp)

                        TextField("Name (optional)", text: $draftName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                            .onSubmit(addWebApp)

                        Button(action: addWebApp) {
                            Label("Add", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }
            }

            // 3. Installed web apps
            SettingsCard(
                title: "Installed",
                icon: "square.grid.2x2.fill",
                iconColor: .blue,
                subtitle: "Each app gets its own tab. Reorder or hide tabs in Behavior & Workspace."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    if store.apps.isEmpty {
                        Text("No web apps yet. Add one above.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(store.apps) { descriptor in
                            webAppRow(descriptor)
                            if descriptor.id != store.apps.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }

            // 4. Presets
            SettingsCard(
                title: "Presets",
                icon: "sparkles",
                iconColor: .purple,
                subtitle: "Ready-made starting points. Adding one is a no-op if you already have it."
            ) {
                HStack(spacing: 8) {
                    // Read from the same bundled config that seeds a new install, so
                    // the list a user can add from is the list they were seeded with
                    // rather than a second copy that can disagree with it.
                    ForEach(presets, id: \.id) { preset in
                        let alreadyAdded = store.apps.contains { $0.id == preset.id }
                        Button {
                            store.addPreset(preset)
                        } label: {
                            Label(
                                alreadyAdded ? preset.name : "Add \(preset.name)",
                                systemImage: alreadyAdded ? "checkmark" : "plus"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(alreadyAdded)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            // Guarded so the read happens once per presentation rather than on every
            // re-render of the pane.
            if presets.isEmpty {
                presets = DefaultWebAppConfig.loadFromBundle()
            }
        }
    }

    // MARK: - Rows

    private func webAppRow(_ descriptor: WebAppDescriptor) -> some View {
        let plugin = registry.plugin(for: descriptor.id)
        let web = plugin?.webController

        return HStack(spacing: 12) {
            WebAppIconView(pluginId: descriptor.id, symbol: plugin?.icon ?? "globe", size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(descriptor.name)
                    .font(.system(size: 13, weight: .bold))
                Text(descriptor.url.host ?? descriptor.url.absoluteString)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let web {
                HStack(spacing: 6) {
                    Text(String(format: "%.0f%%", web.currentZoom * 100))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)

                    Button { web.zoomOut() } label: {
                        Image(systemName: "minus").font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .help("Zoom Out")

                    Button { web.zoomIn() } label: {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .help("Zoom In")
                }
            }

            Button {
                appState.expand(tab: .plugin(id: descriptor.id))
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }

            Button {
                store.setEnabled(!descriptor.isEnabled, id: descriptor.id)
            } label: {
                Image(systemName: descriptor.isEnabled ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.bordered)
            .help(descriptor.isEnabled ? "Disable" : "Enable")

            Button(role: .destructive) {
                store.remove(id: descriptor.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .help("Remove this web app")
        }
    }

    // MARK: - Actions

    /// Validates through the same parser the tests exercise, so the rejection the
    /// user sees is the rejection that is guarded.
    private func addWebApp() {
        let parsed = WebAppDescriptor.parse(draftURL)

        guard let url = parsed.url else {
            validationMessage = parsed.failureReason
            return
        }

        let id = WebAppDescriptor.identifier(for: url)
        guard !store.apps.contains(where: { $0.id == id }) else {
            validationMessage = "That web app is already installed."
            return
        }

        store.add(url: url, name: draftName.isEmpty ? nil : draftName)
        draftURL = ""
        draftName = ""
        validationMessage = nil
    }
}
