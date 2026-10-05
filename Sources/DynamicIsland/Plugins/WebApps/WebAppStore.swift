import Foundation
import Combine

/// Persistence for the user's web app list.
///
/// Seeded once and then owned entirely by the user: because the seed flag is
/// recorded, deleting a seeded app does not resurrect it on the next launch.
public class WebAppStore: ObservableObject {
    public static let shared = WebAppStore()

    private static let storageKey = "webAppDescriptors"
    private static let seededKey = "webAppsSeededV1"

    @Published public private(set) var apps: [WebAppDescriptor] = []

    private let defaults: UserDefaults

    /// The first-launch seed list.
    ///
    /// A parameter rather than an inline call to `DefaultWebAppConfig.loadFromBundle()`
    /// because that reads `Bundle.main`, which the headless test target cannot do. With
    /// the list injected, the rule that actually matters — that seeding happens
    /// exactly once — becomes testable instead of assumed. The shared instance
    /// supplies the bundle as the default.
    private let seedDefaults: [WebAppDescriptor]

    public init(
        defaults: UserDefaults = .standard,
        seedDefaults: [WebAppDescriptor] = DefaultWebAppConfig.loadFromBundle()
    ) {
        self.defaults = defaults
        self.seedDefaults = seedDefaults

        let decoded: [WebAppDescriptor]
        if let data = defaults.data(forKey: Self.storageKey),
           let restored = try? JSONDecoder().decode([WebAppDescriptor].self, from: data) {
            decoded = restored
        } else {
            decoded = []
        }

        // Seed exactly once. The flag is what makes deletion stick: without it a
        // user who removed the default would find it back after a relaunch.
        //
        // The list comes from the bundled config, so adding a default is a resource
        // edit rather than a code change — but because the flag is written on the
        // first launch either way, a default shipped later reaches *new* installs
        // only. That is the intended trade: the alternative makes deletion
        // impossible, which is the worse failure.
        let alreadySeeded = defaults.bool(forKey: Self.seededKey)
        if decoded.isEmpty && !alreadySeeded {
            self.apps = seedDefaults
        } else {
            self.apps = decoded
        }

        // Persist is deliberately NOT called from here. `persist` notifies the
        // registry, which reads `WebAppStore.shared` — and during this initializer
        // that static is still inside its own `swift_once`, so re-entering it
        // deadlocks. Seeding writes only what the next launch needs.
        if let data = try? JSONEncoder().encode(apps) {
            defaults.set(data, forKey: Self.storageKey)
        }
        defaults.set(true, forKey: Self.seededKey)
    }

    // MARK: - Queries

    public func descriptor(for id: String) -> WebAppDescriptor? {
        apps.first { $0.id == id }
    }

    public func enabledApps() -> [WebAppDescriptor] {
        apps.filter(\.isEnabled)
    }

    // MARK: - Mutations
    //
    // Each mutation reassigns the whole array so `didSet`-style persistence cannot
    // be bypassed by a partial in-place edit, then tells the registry to resync.

    /// Adds a web app, returning the stored descriptor.
    ///
    /// Rejects a URL that already exists, so adding the same app twice cannot create
    /// two plugins and tabs fighting over one id.
    @discardableResult
    public func add(url: URL, name: String? = nil) -> WebAppDescriptor? {
        let id = WebAppDescriptor.identifier(for: url)
        guard !apps.contains(where: { $0.id == id }) else { return nil }

        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let descriptor = WebAppDescriptor(
            id: id,
            name: trimmedName.isEmpty ? WebAppDescriptor.displayName(for: url) : trimmedName,
            url: url
        )

        apps.append(descriptor)
        persist()
        return descriptor
    }

    /// Adds a preset by id. A no-op when already present, so the button is
    /// idempotent instead of a duplicate machine.
    @discardableResult
    public func addPreset(_ preset: WebAppDescriptor) -> WebAppDescriptor? {
        guard !apps.contains(where: { $0.id == preset.id }) else { return nil }
        apps.append(preset)
        persist()
        return preset
    }

    public func remove(id: String) {
        guard apps.contains(where: { $0.id == id }) else { return }
        apps.removeAll { $0.id == id }
        persist()
    }

    public func setEnabled(_ enabled: Bool, id: String) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        apps[index].isEnabled = enabled
        persist()
    }

    public func rename(id: String, to name: String) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        apps[index].name = trimmed
        persist()
    }

    public func updateURL(id: String, to url: URL) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        apps[index].url = url
        // The id is intentionally not recomputed: identity has to survive a URL edit
        // or the tab, icon, and saved sound would all break on a rename.
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(apps) else { return }
        defaults.set(data, forKey: Self.storageKey)
        WebAppRegistry.shared.sync()
    }
}

/// Bridges the stored descriptors to live `IslandPlugin` instances.
///
/// The registry is the single owner of the mapping from descriptor to plugin, so
/// adding, editing, or removing a web app is a resync rather than a pile of
/// scattered call sites — and the tab list, the icon pipeline, and the ear all
/// observe the same list.
public class WebAppRegistry: ObservableObject {
    public static let shared = WebAppRegistry()

    /// Live plugins, one per stored descriptor, in user-visible order.
    @Published public private(set) var plugins: [WebAppPlugin] = []

    private var isSyncing = false

    private init() {}

    public func plugin(for id: String) -> WebAppPlugin? {
        plugins.first { $0.id == id }
    }

    public var enabledPlugins: [WebAppPlugin] {
        plugins.filter(\.isEnabled)
    }

    /// Reconciles the plugin list with the stored descriptors.
    ///
    /// Existing instances are reused so a live web session and its scroll position
    /// survive an unrelated edit elsewhere; only the set of ids actually changes.
    public func sync() {
        let descriptors = WebAppStore.shared.apps
        let incomingIds = Set(descriptors.map(\.id))

        let removed = plugins.filter { !incomingIds.contains($0.id) }
        for plugin in removed {
            PluginManager.shared.unregister(id: plugin.id)
        }
        plugins.removeAll { !incomingIds.contains($0.id) }

        for descriptor in descriptors {
            if let index = plugins.firstIndex(where: { $0.id == descriptor.id }) {
                guard plugins[index].descriptor != descriptor else { continue }
                plugins[index].apply(descriptor)
            } else {
                let plugin = WebAppPlugin(descriptor: descriptor)
                plugins.append(plugin)
                PluginManager.shared.register(plugin: plugin)
            }
        }

        // Preserve the user's tab order, which is keyed by id.
        let ordered = plugins.sorted { lhs, rhs in
            orderIndex(of: lhs.id) < orderIndex(of: rhs.id)
        }
        if ordered.map(\.id) != plugins.map(\.id) {
            plugins = ordered
        }

        PluginManager.shared.notifyPluginStateChanged()
    }

    private func orderIndex(of id: String) -> Int {
        let order = SettingsManager.shared.customTabOrder
        return order.firstIndex(of: id) ?? Int.max
    }
}
