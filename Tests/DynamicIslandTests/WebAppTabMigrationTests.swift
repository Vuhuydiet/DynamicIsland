import XCTest
@testable import DynamicIsland

/// Guards the `"Messenger"` -> seeded-web-app-id mapping.
///
/// `customTabOrder` and `hiddenTabs` both persist raw tab strings, and `"Messenger"`
/// was written by an earlier build. Without this migration an upgrading user silently
/// loses their tab order and a tab they had chosen to hide reappears — a data loss
/// that is invisible in testing and obvious only to that one user.
final class WebAppTabMigrationTests: XCTestCase {

    private let legacy = "Messenger"
    private let seededId = "com.dynamicisland.plugin.messenger"

    // MARK: - The mapping itself

    func testLegacyMessengerMapsToTheSeededIdentifier() {
        XCTAssertEqual(IslandTab.migrateLegacyTabID(legacy), seededId)
    }

    func testBuiltInToolIDsAreUntouched() {
        for id in ["Media", "Timer", "Clipboard", "Notes"] {
            XCTAssertEqual(IslandTab.migrateLegacyTabID(id), id)
        }
    }

    func testAnUnknownPluginIDIsPassedThroughUnchanged() {
        XCTAssertEqual(
            IslandTab.migrateLegacyTabID("com.dynamicisland.webapp.web.slack.com"),
            "com.dynamicisland.webapp.web.slack.com"
        )
    }

    func testMappingIsIdempotent() {
        // Matters because the migration is applied on every read, not once at launch.
        let once = IslandTab.migrateLegacyTabID(legacy)
        XCTAssertEqual(IslandTab.migrateLegacyTabID(once), once)
    }

    // MARK: - Ordering

    func testLegacyIDResolvesToTheSamePositionInTabOrder() {
        // A user who put Messenger first must still find it first after upgrading.
        let stored = ["Notes", legacy, "Media"]
        let migrated = stored.map(IslandTab.migrateLegacyTabID)

        XCTAssertEqual(migrated, ["Notes", seededId, "Media"])
    }

    func testEveryPersistedOrderEntrySurvivesMigration() {
        let stored = ["Media", legacy, "Timer", "com.dynamicisland.webapp.web.slack.com"]
        let migrated = stored.map(IslandTab.migrateLegacyTabID)

        XCTAssertEqual(migrated.count, stored.count, "Migration must not drop entries")
        XCTAssertEqual(Set(migrated), Set([seededId, "Media", "Timer", "com.dynamicisland.webapp.web.slack.com"]))
    }

    // MARK: - Visibility

    func testAHiddenMessengerStaysHidden() {
        let hiddenTabs: Set<String> = [legacy]
        let resolved = Set(hiddenTabs.map(IslandTab.migrateLegacyTabID))
        XCTAssertTrue(resolved.contains(seededId), "A tab the user hid must not reappear")
    }

    func testMigrationCannotResurrectAnotherHiddenTab() {
        let hiddenTabs: Set<String> = ["Timer", legacy]
        let resolved = Set(hiddenTabs.map(IslandTab.migrateLegacyTabID))
        XCTAssertEqual(resolved, ["Timer", seededId])
    }

    // MARK: - Tab construction

    func testLegacyRawValueStillBuildsAPluginTab() {
        // `init?(rawValue:)` runs on every persisted and deep-linked id, so a legacy
        // value must land on `.plugin(id:)` — never on a tool case.
        guard let tab = IslandTab(rawValue: legacy) else {
            return XCTFail("Legacy raw value failed to construct a tab")
        }
        XCTAssertEqual(tab, .plugin(id: seededId))
    }

    func testToolRawValuesStillBuildToolTabs() {
        XCTAssertEqual(IslandTab(rawValue: "Media"), .media)
        XCTAssertEqual(IslandTab(rawValue: "Notes"), .notes)
    }

    // MARK: - Labels

    func testNoTabLabelLeaksAReverseDNSId() {
        // The regression this guards: `displayName` existed but the tab pill, the
        // Behaviour list, and the General preview all rendered `rawValue`, so the
        // user saw `com.dynamicisland.plugin.messenger` as the tab title. Every
        // surface that shows a tab label must go through `displayName`.
        for raw in ["Media", "Timer", "Clipboard", "Notes"] {
            guard let tab = IslandTab(rawValue: raw) else { continue }
            XCTAssertFalse(tab.displayName.contains("com."), "\(raw) leaked an id")
            XCTAssertFalse(tab.displayName.contains("."), "\(raw) leaked a dotted id")
        }
    }

    func testToolLabelsAreUnchangedByThisMigration() {
        XCTAssertEqual(IslandTab.media.displayName, "Media")
        XCTAssertEqual(IslandTab.timer.displayName, "Timer")
        XCTAssertEqual(IslandTab.clipboard.displayName, "Clipboard")
        XCTAssertEqual(IslandTab.notes.displayName, "Notes")
    }

    func testAnUnresolvablePluginIdDoesNotClaimToBeSomethingItIsNot() {
        // `customTabOrder` keeps an id after the app is deleted, so this branch is
        // reachable. A bare "Plugin" would be a confident wrong answer repeated for
        // every removed app; the id is ugly but it is true.
        let ghost = IslandTab.plugin(id: "com.dynamicisland.webapp.gone.example.com")
        XCTAssertFalse(ghost.displayName.isEmpty)
        XCTAssertNotEqual(ghost.displayName, "Plugin")
    }
}

/// Guards the seed-once rule: a user who deletes a default must not find it back.
///
/// This is the invariant the whole "seeded once" design exists to protect, and it is
/// invisible until it breaks — a default reappearing on the next launch, weeks later,
/// with no way for the user to remove it permanently. So it is asserted directly
/// rather than inferred from the flag being written.
final class WebAppStoreSeedingTests: XCTestCase {

    private let messenger = WebAppDescriptor(
        id: "com.dynamicisland.plugin.messenger",
        name: "Messenger",
        url: URL(string: "https://www.messenger.com/")!
    )

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "WebAppStoreSeedingTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func store(seeded: [WebAppDescriptor]? = nil) -> WebAppStore {
        WebAppStore(defaults: defaults, seedDefaults: seeded ?? [messenger])
    }

    func testFirstLaunchSeedsTheDefaults() {
        XCTAssertEqual(store().apps.map(\.id), [messenger.id])
    }

    /// The one that matters: a user who deletes the default and relaunches must not
    /// get it back.
    func testDeletingASeededAppSurvivesRelaunch() {
        let first = store()
        first.remove(id: messenger.id)
        XCTAssertTrue(first.apps.isEmpty)

        // Relaunch: a fresh store over the same persisted defaults.
        let relaunched = store()
        XCTAssertTrue(relaunched.apps.isEmpty, "a deleted default was resurrected on relaunch")
    }

    /// The flag is written even when the config yields nothing, so a broken config
    /// cannot resurrect defaults on a later launch once the user has cleared them.
    func testAnEmptySeedListStillRecordsTheFlag() {
        let empty = store(seeded: [])
        XCTAssertTrue(empty.apps.isEmpty)
        XCTAssertTrue(defaults.bool(forKey: "webAppsSeededV1"))

        let relaunched = store()
        XCTAssertTrue(relaunched.apps.isEmpty)
    }

    /// A shipped default added in a later version reaches new installs only. That is
    /// the accepted trade — re-reading the config every launch would make deletion
    /// impossible — so it is pinned here rather than left to chance.
    func testALaterShippedDefaultDoesNotReachAnExistingInstall() {
        let slack = WebAppDescriptor(
            id: "com.dynamicisland.webapp.web.slack.com",
            name: "Slack",
            url: URL(string: "https://app.slack.com/client")!
        )
        _ = store(seeded: [messenger])

        let relaunched = store(seeded: [messenger, slack])
        XCTAssertEqual(relaunched.apps.map(\.id), [messenger.id],
                       "existing installs must not silently gain new defaults")
    }

    func testRenamingASeededAppIsNotUndoneByRelaunch() {
        let first = store()
        first.rename(id: messenger.id, to: "Chat")

        let relaunched = store()
        XCTAssertEqual(relaunched.apps.first?.name, "Chat")
    }

    func testDisablingASeededAppIsNotUndoneByRelaunch() {
        let first = store()
        first.setEnabled(false, id: messenger.id)

        let relaunched = store()
        XCTAssertEqual(relaunched.apps.first?.isEnabled, false)
    }
}
