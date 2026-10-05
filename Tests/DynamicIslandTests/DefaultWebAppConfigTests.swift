import XCTest
import Foundation
@testable import DynamicIsland

/// Guards the strict `Codable` conformance that both the shipped config and the
/// persisted list depend on.
///
/// Swift's synthesised conformance ignores unknown keys, so a typo in
/// `DefaultWebApps.json` would otherwise decode into a working app with a silently
/// missing field and no error anywhere (AGENTS.md §1.1).
final class WebAppDescriptorStrictDecodingTests: XCTestCase {

    private func descriptor(from json: String) throws -> WebAppDescriptor {
        try JSONDecoder().decode(WebAppDescriptor.self, from: Data(json.utf8))
    }

    func testDecodesAllFourFields() throws {
        let d = try descriptor(from: #"{"id":"a","name":"A","url":"https://a.com/","isEnabled":false}"#)
        XCTAssertEqual(d.id, "a")
        XCTAssertEqual(d.name, "A")
        XCTAssertEqual(d.url, URL(string: "https://a.com/"))
        XCTAssertFalse(d.isEnabled)
    }

    func testIsEnabledDefaultsToTrueWhenAbsent() throws {
        let d = try descriptor(from: #"{"id":"a","name":"A","url":"https://a.com/"}"#)
        XCTAssertTrue(d.isEnabled)
    }

    func testUnknownKeyThrows() {
        XCTAssertThrowsError(
            try descriptor(from: #"{"id":"a","name":"A","url":"https://a.com/","favcionURL":"https://a.com/i.png"}"#)
        ) { error in
            guard case WebAppDescriptor.DecodeError.unknownKeys(let keys)? = error as? WebAppDescriptor.DecodeError else {
                return XCTFail("expected unknownKeys, got \(error)")
            }
            XCTAssertEqual(keys, ["favcionURL"])
        }
    }

    func testEveryUnknownKeyIsReported() {
        XCTAssertThrowsError(
            try descriptor(from: #"{"id":"a","name":"A","url":"https://a.com/","typo":1,"favcionURL":"x"}"#)
        ) { error in
            guard case WebAppDescriptor.DecodeError.unknownKeys(let keys)? = error as? WebAppDescriptor.DecodeError else {
                return XCTFail("expected unknownKeys, got \(error)")
            }
            XCTAssertEqual(Set(keys), Set(["typo", "favcionURL"]))
        }
    }

    func testMissingRequiredKeyStillThrows() {
        XCTAssertThrowsError(try descriptor(from: #"{"id":"a","name":"A"}"#))
    }

    /// Encoding is untouched: the persisted list must keep round-tripping, or every
    /// saved web app would be lost on upgrade.
    func testRoundTripThroughEncodingPreservesEveryField() throws {
        let original = WebAppDescriptor(id: "a", name: "A", url: URL(string: "https://a.com/x")!, isEnabled: false)
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(WebAppDescriptor.self, from: data)
        XCTAssertEqual(restored, original)
    }
}

/// Guards the shipped default-app list: what it decodes to, and what survives a bad
/// edit.
///
/// `decode` never throws, so a broken config would otherwise be indistinguishable
/// from an empty one — and a config that silently seeds nothing looks exactly like a
/// working app with no defaults, which is the kind of quiet failure §2.6 rules out.
final class DefaultWebAppConfigTests: XCTestCase {

    private func data(_ json: String) -> Data { Data(json.utf8) }

    func testDecodesEntries() {
        let apps = DefaultWebAppConfig.decode(data("""
        [{"id":"com.x","name":"X","url":"https://x.com/","isEnabled":true}]
        """))
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps[0].id, "com.x")
        XCTAssertEqual(apps[0].url, URL(string: "https://x.com/"))
    }

    func testMalformedJSONYieldsEmpty() {
        XCTAssertTrue(DefaultWebAppConfig.decode(data("{not json")).isEmpty)
    }

    func testEmptyArrayYieldsEmpty() {
        XCTAssertTrue(DefaultWebAppConfig.decode(data("[]")).isEmpty)
    }

    func testNonArrayYieldsEmpty() {
        XCTAssertTrue(DefaultWebAppConfig.decode(data(#"{"id":"a"}"#)).isEmpty)
    }

    /// One bad entry must not void the rest: the file is hand-edited, and a single
    /// typo should not cost the user every other default.
    func testOneBadEntryDoesNotVoidTheRest() {
        let apps = DefaultWebAppConfig.decode(data("""
        [{"id":"good1","name":"Good","url":"https://good.com/"},
         {"id":"bad","name":"Bad","url":"https://x.com/","isEnabled":"yes"},
         {"id":"good2","name":"Good2","url":"https://good2.com/"}]
        """))
        XCTAssertEqual(apps.map(\.id), ["good1", "good2"])
    }

    func testEntryWithUnknownKeyIsDroppedNotIgnored() {
        let apps = DefaultWebAppConfig.decode(data("""
        [{"id":"good1","name":"Good","url":"https://good.com/"},
         {"id":"typo","name":"Typo","url":"https://t.com/","isenable":true}]
        """))
        XCTAssertEqual(apps.map(\.id), ["good1"], "a typo'd key must drop the entry, not half-apply it")
    }

    /// The test that keeps the shipped file honest over time: a bad edit fails here
    /// instead of silently seeding nothing on a user's machine.
    func testShippedConfigFileDecodes() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // DynamicIslandTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
        let url = root.appendingPathComponent("Resources/DefaultWebApps.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "shipped config is missing")

        let apps = DefaultWebAppConfig.decode(try Data(contentsOf: url))
        XCTAssertFalse(apps.isEmpty, "Resources/DefaultWebApps.json decoded to nothing")
        XCTAssertTrue(
            apps.contains { $0.id == "com.dynamicisland.plugin.messenger" },
            "the legacy Messenger id must survive: the shipped icon and persisted sound overrides are keyed by it"
        )
    }
}
