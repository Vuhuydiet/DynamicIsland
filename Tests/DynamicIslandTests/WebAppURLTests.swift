import XCTest
import Foundation
@testable import DynamicIsland

/// Guards `WebAppDescriptor`'s parsing, identity, and naming rules.
///
/// These are the pure functions the "Add Web App" field depends on, so a regression
/// here is a tab that loads nothing or two apps fighting over one id — both of which
/// are only otherwise visible as a user report (AGENTS.md §1.1).
final class WebAppURLTests: XCTestCase {

    // MARK: - Scheme defaulting

    func testBareHostIsUpgradedToHTTPS() {
        let parsed = WebAppDescriptor.parse("messenger.com")
        XCTAssertEqual(parsed.url?.absoluteString, "https://messenger.com")
    }

    func testBareHostWithWwwAndPathIsAccepted() {
        let parsed = WebAppDescriptor.parse("web.whatsapp.com/chat")
        XCTAssertEqual(parsed.url?.host, "web.whatsapp.com")
        XCTAssertEqual(parsed.url?.scheme, "https")
    }

    func testExplicitHTTPSIsPreserved() {
        let parsed = WebAppDescriptor.parse("https://slack.com")
        XCTAssertEqual(parsed.url?.absoluteString, "https://slack.com")
    }

    func testWhitespaceIsTrimmed() {
        let parsed = WebAppDescriptor.parse("   messenger.com   ")
        XCTAssertEqual(parsed.url?.host, "messenger.com")
    }

    // MARK: - Rejections

    func testEmptyInputIsRejectedAsEmpty() {
        XCTAssertEqual(WebAppDescriptor.parse(""), .empty)
        XCTAssertEqual(WebAppDescriptor.parse("    "), .empty)
    }

    func testNonHTTPSchemeIsRejected() {
        XCTAssertEqual(WebAppDescriptor.parse("ftp://files.example.com"), .notHTTP)
    }

    func testSchemeIsNotDoublePrefixed() {
        // A blind "https://" prefix would produce "https://ftp://x", which parses
        // as a host of "ftp" and silently loads the wrong thing.
        let parsed = WebAppDescriptor.parse("ftp://files.example.com")
        XCTAssertEqual(parsed, .notHTTP)
    }

    func testHostlessInputIsRejected() {
        XCTAssertEqual(WebAppDescriptor.parse("https://"), .noHost)
    }

    func testEveryRejectionCarriesAUserFacingReason() {
        XCTAssertNotNil(WebAppDescriptor.parse("").failureReason)
        XCTAssertNotNil(WebAppDescriptor.parse("ftp://x.com").failureReason)
        XCTAssertNotNil(WebAppDescriptor.parse("https://").failureReason)
        XCTAssertNil(WebAppDescriptor.parse("messenger.com").failureReason)
    }

    // MARK: - Identity

    func testIdentifierIsDerivedFromHostAlone() {
        let bare = WebAppDescriptor.identifier(for: URL(string: "https://messenger.com")!)
        let withPath = WebAppDescriptor.identifier(for: URL(string: "https://messenger.com/chat/42?x=1")!)
        XCTAssertEqual(bare, withPath, "Editing a path must not orphan the saved tab, icon, or sound")
    }

    func testIdentifierIsStableAcrossCalls() {
        let url = URL(string: "https://web.slack.com")!
        XCTAssertEqual(
            WebAppDescriptor.identifier(for: url),
            WebAppDescriptor.identifier(for: url)
        )
    }

    func testDifferentHostsGetDifferentIdentifiers() {
        let a = WebAppDescriptor.identifier(for: URL(string: "https://messenger.com")!)
        let b = WebAppDescriptor.identifier(for: URL(string: "https://slack.com")!)
        XCTAssertNotEqual(a, b)
    }

    func testIdentifierIsNamespacedAwayFromPluginIDs() {
        let id = WebAppDescriptor.identifier(for: URL(string: "https://messenger.com")!)
        XCTAssertTrue(id.hasPrefix("com.dynamicisland.webapp."))
    }

    func testSeededMessengerKeepsItsLegacyIdentifier() {
        // The shipped messenger.png icon and any persisted sound override are keyed
        // by this id, so changing it would break both for upgrading users.
        XCTAssertEqual(WebAppLegacyID.messenger, "com.dynamicisland.plugin.messenger")
    }

    /// The config and the compiled-in legacy id must agree.
    ///
    /// The id is written down twice — once as a constant that legacy migration reads,
    /// once as data in `DefaultWebApps.json` — and those two copies can drift. If
    /// they do, a new install seeds an app under an id that the shipped icon and any
    /// restored sound override do not recognise, which is invisible until a user
    /// notices a missing icon on their one seeded app.
    func testShippedConfigUsesTheLegacyMessengerIdentifier() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/DefaultWebApps.json"))
        let apps = DefaultWebAppConfig.decode(data)
        let messenger = apps.first { $0.url.host?.contains("messenger") == true }
        XCTAssertEqual(messenger?.id, WebAppLegacyID.messenger)
    }

    // MARK: - Naming

    func testDisplayNameStripsWwwAndSuffix() {
        XCTAssertEqual(
            WebAppDescriptor.displayName(for: URL(string: "https://www.messenger.com/")!),
            "Messenger"
        )
    }

    func testDisplayNameHandlesMultiLabelHosts() {
        XCTAssertEqual(
            WebAppDescriptor.displayName(for: URL(string: "https://web.whatsapp.com")!),
            "Whatsapp"
        )
    }

    func testDisplayNameIsNeverEmpty() {
        for raw in ["https://messenger.com", "https://web.slack.com", "https://a.b.c.example.com"] {
            let name = WebAppDescriptor.displayName(for: URL(string: raw)!)
            XCTAssertFalse(name.isEmpty, "\(raw) produced an empty label")
        }
    }

    // MARK: - Icon lookup

    func testIconLabelCandidatesFindTheBrandNotTheSuffix() {
        // Without skipping platform labels, the last component is "com" and a file
        // named whatsapp.png would be unreachable.
        let candidates = PluginIconManager.iconLabelCandidates(
            for: "com.dynamicisland.webapp.web.web.whatsapp.com"
        )
        XCTAssertTrue(candidates.contains("whatsapp"))
        XCTAssertFalse(candidates.first == "com")
    }

    func testIconLabelCandidatesResolveSingleLabelHosts() {
        let candidates = PluginIconManager.iconLabelCandidates(
            for: "com.dynamicisland.webapp.web.messenger.com"
        )
        XCTAssertTrue(candidates.contains("messenger"))
    }

    func testIconLabelCandidatesIncludeTheSeededMessengerId() {
        // The shipped icon is messenger.png and the seeded id keeps its legacy form.
        let candidates = PluginIconManager.iconLabelCandidates(
            for: "com.dynamicisland.plugin.messenger"
        )
        XCTAssertTrue(candidates.contains("messenger"))
    }
}
