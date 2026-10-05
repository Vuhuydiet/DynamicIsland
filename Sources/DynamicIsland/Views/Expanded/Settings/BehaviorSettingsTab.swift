import SwiftUI

// MARK: - Pane 3: Behavior & tabs

// MARK: - Tab 3: Behavior & Tabs Settings Tab

public struct BehaviorSettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared
    @StateObject private var tabDragCoordinator = TabDragCoordinator()

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Behavior & Workspace")
                    .font(.system(size: 17, weight: .bold))
                Text("Configure how Dynamic Island triggers, docks, and what tools are accessible.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 1. Island Mode
            SettingsCard(
                title: "Island Docking Mode",
                icon: "macbook",
                iconColor: .teal,
                subtitle: "Specify how Dynamic Island binds to built-in screens and external displays."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $settings.notchStyle) {
                        ForEach(NotchStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text("Auto Detect anchors seamlessly to the hardware camera notch on MacBooks, and floats as an elegant pill on external monitors.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // 2. Expansion Trigger & Delay
            SettingsCard(
                title: "Expansion Triggers & Hover Timing",
                icon: "cursorarrow.rays",
                iconColor: .blue,
                subtitle: "Control how cursor contact expands the island."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsRow(
                        title: "Trigger Mode:",
                        subtitle: "Hover & Click expands when hovering cursor over notch. Click Only expands on mouse click."
                    ) {
                        Picker("", selection: $settings.expandTrigger) {
                            ForEach(ExpandTrigger.allCases) { trig in
                                Text(trig.rawValue).tag(trig)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 190)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Hover Delay Sensitivity:")
                                .font(.system(size: 12.5, weight: .medium))
                            Spacer()
                            if settings.hoverDelay <= 0.005 {
                                Text("Instant (0 ms)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            } else {
                                Text(String(format: "%.0f ms", settings.hoverDelay * 1000))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Slider(value: $settings.hoverDelay, in: 0.0...0.60, step: 0.01)
                    }
                }
            }

            // 3. Tab Visibility & Ordering
            let allTabs = IslandTab.allCases
            SettingsCard(
                title: "Island Tabs & Order",
                icon: "arrow.up.arrow.down.square.fill",
                iconColor: .indigo,
                subtitle: "Drag a tab (or use the arrows) to rearrange. Toggle visibility independently.",
                trailing: AnyView(
                    Button(action: {
                        withAnimation(IslandSpring.tabSlide) {
                            settings.resetTabOrder()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Reset Order")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(settings.customTabOrder.isEmpty ? .secondary.opacity(0.4) : .primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(settings.customTabOrder.isEmpty ? 0.02 : 0.06))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.customTabOrder.isEmpty)
                    .help("Reset tabs to original default order")
                )
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(allTabs.enumerated()), id: \.element.id) { idx, tab in
                        if idx > 0 { Divider().padding(.vertical, 2) }
                        let isDragging = tabDragCoordinator.draggingTab == tab
                        HStack(spacing: 10) {
                            // 0. Drag handle
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary.opacity(isDragging ? 0.9 : 0.55))
                                .frame(width: 18, height: 22)
                                .contentShape(Rectangle())
                                .help("Drag to reorder \(tab.displayName)")
                                .gesture(
                                    DragGesture(minimumDistance: 3)
                                        .onChanged { value in
                                            tabDragCoordinator.onDragChanged(
                                                tab: tab,
                                                translation: value.translation.height,
                                                orderedTabs: allTabs,
                                                slotStep: 44,
                                                visibleOnly: false
                                            )
                                        }
                                        .onEnded { value in
                                            tabDragCoordinator.onDragEnded(
                                                tab: tab,
                                                translation: value.translation.height
                                            )
                                        }
                                )

                            // 1. Order Index Badge
                            Text("#\(idx + 1)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 20)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            // 2. Tab Icon
                            tab.iconView(size: 15)
                                .frame(width: 20, height: 20)

                            // 3. Tab Title & Subtitle
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tab.displayName)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(settings.isTabVisible(tab) ? .primary : .secondary)

                                Text(tabSubtitle(for: tab))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // 4. Move Up / Down Arrow Buttons
                            HStack(spacing: 4) {
                                Button(action: {
                                    withAnimation(IslandSpring.tabSlide) {
                                        settings.moveTabUp(tab)
                                    }
                                }) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(idx > 0 ? .primary : .secondary.opacity(0.25))
                                        .frame(width: 22, height: 22)
                                        .background(Color.white.opacity(idx > 0 ? 0.08 : 0.02))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                                .disabled(idx == 0)
                                .help("Move \(tab.displayName) up")

                                Button(action: {
                                    withAnimation(IslandSpring.tabSlide) {
                                        settings.moveTabDown(tab)
                                    }
                                }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(idx < allTabs.count - 1 ? .primary : .secondary.opacity(0.25))
                                        .frame(width: 22, height: 22)
                                        .background(Color.white.opacity(idx < allTabs.count - 1 ? 0.08 : 0.02))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                                .disabled(idx >= allTabs.count - 1)
                                .help("Move \(tab.displayName) down")
                            }

                            // 5. Divider
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 1, height: 16)
                                .padding(.horizontal, 4)

                            // 6. Visibility Toggle
                            Toggle("", isOn: Binding(
                                get: { settings.isTabVisible(tab) },
                                set: { visible in
                                    if visible {
                                        settings.hiddenTabs.remove(tab.rawValue)
                                    } else {
                                        let remaining = IslandTab.allCases.filter { settings.isTabVisible($0) }
                                        if remaining.count > 1 {
                                            settings.hiddenTabs.insert(tab.rawValue)
                                        }
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(isDragging ? 0.08 : 0))
                        )
                        .offset(y: isDragging ? tabDragCoordinator.dragOffset : 0)
                        .zIndex(isDragging ? 20 : 1)
                        .scaleEffect(isDragging ? 1.02 : 1.0)
                        .shadow(color: isDragging ? .black.opacity(0.18) : .clear, radius: isDragging ? 8 : 0, y: 2)
                    }
                }
                .animation(IslandSpring.tabSlide, value: allTabs.map(\.id))
            }

            // 4. File Drop Shelf
            SettingsCard(
                title: "File Drop Shelf Layout",
                icon: "tray.and.arrow.down.fill",
                iconColor: .orange,
                subtitle: "Files parked at the notch appear in a dedicated secondary tray below the island."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsRow(title: "Card Presentation:") {
                        Picker("", selection: $settings.dropShelfCardStyle) {
                            ForEach(DropShelfCardStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }

                    Text("Drag any file, folder, or image directly towards the notch to expand the drop shelf and park items for rapid drag-out.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func tabSubtitle(for tab: IslandTab) -> String {
        switch tab {
        case .media:
            return "Now playing audio, album art & controls"
        case .timer:
            return "Multi-timer countdowns & stopwatch laps"
        case .clipboard:
            return "Clipboard history & quick copy items"
        case .notes:
            return "Persistent scratchpad & quick notes"
        case .plugin(let id):
            if let plugin = PluginManager.shared.plugin(for: id) {
                return plugin.subtitle
            }
            return "External island plugin (\(id))"
        }
    }
}

