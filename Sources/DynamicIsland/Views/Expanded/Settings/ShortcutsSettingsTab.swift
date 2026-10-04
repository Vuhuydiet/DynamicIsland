import SwiftUI

// MARK: - Pane 6: Shortcuts

// MARK: - Tab 6: Shortcuts Settings Tab

public struct ShortcutsSettingsTab: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Gestures & Shortcuts")
                    .font(.system(size: 17, weight: .bold))
                Text("Quick reference for keyboard key bindings and notch mouse gestures.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            SettingsCard(
                title: "Keyboard Shortcuts",
                icon: "command",
                iconColor: .indigo,
                subtitle: "Global keyboard triggers available system-wide."
            ) {
                VStack(spacing: 8) {
                    ShortcutRow(title: "Toggle Dynamic Island", shortcut: "⌥ ⌘ I")
                    Divider()
                    ShortcutRow(title: "Collapse Island", shortcut: "⎋ Esc")
                    Divider()
                    ShortcutRow(title: "Lock Screen", shortcut: "⌃ ⌘ Q")
                }
            }
            
            SettingsCard(
                title: "Mouse & Drag Gestures",
                icon: "cursorarrow.rays",
                iconColor: .blue,
                subtitle: "Notch hover zones and file parking shortcuts."
            ) {
                VStack(spacing: 8) {
                    ShortcutRow(title: "Hover over Notch", shortcut: "Peek & Expand")
                    Divider()
                    ShortcutRow(title: "Click Compact Island", shortcut: "Open / Expand")
                    Divider()
                    ShortcutRow(title: "Drag Any File to Notch", shortcut: "Open Drop Shelf")
                    Divider()
                    ShortcutRow(title: "Click Pin Icon", shortcut: "Lock Island Open")
                }
            }
        }
    }
}

public struct ShortcutRow: View {
    public let title: String
    public let shortcut: String
    
    public var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
            Spacer()
            KeyCapView(text: shortcut)
        }
        .padding(.vertical, 2)
    }
}

