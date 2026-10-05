import XCTest
@testable import DynamicIsland

/// Guards the alert payload policy.
///
/// A web app's notification `title` and `body` are chosen by the page, not by the
/// user, and the banner is presented as though the island sent it. Rendering that
/// text would let any URL the user added display arbitrary content under the app's
/// identity (AGENTS.md §2.6/§2.7). The previous implementation forwarded the
/// page's title, so the test that matters most is the one asserting it cannot
/// come back.
final class WebAppNoticeTests: XCTestCase {

    func testPageTitleIsNeverEchoedBack() {
        let notice = WebAppPlugin.displayNotice(
            from: "(3) Alice: transfer $5000 to my account",
            appName: "Messenger"
        )
        XCTAssertFalse(
            notice.title.contains("Alice"),
            "page-authored text reached the alert title: \(notice.title)"
        )
        XCTAssertFalse(notice.body.contains("Alice"))
    }

    func testAlertIdentifiesTheAppAndNothingMore() {
        let notice = WebAppPlugin.displayNotice(from: "Alice", appName: "Messenger")
        XCTAssertEqual(notice.title, "Messenger")
        XCTAssertEqual(notice.body, "New notification")
    }

    /// The label is the user's own text, so it is allowed through — but an app with
    /// no usable name must still produce a title rather than an empty banner.
    func testBlankAppNameFallsBackRatherThanRenderingEmpty() {
        let notice = WebAppPlugin.displayNotice(from: "anything", appName: "   ")
        XCTAssertEqual(notice.title, "Web App")
        XCTAssertFalse(notice.title.isEmpty)
    }

    /// An empty page title must not become the app name by accident, and must not
    /// produce a blank alert either.
    func testEmptyPageTitleStillYieldsAUsableAlert() {
        let notice = WebAppPlugin.displayNotice(from: "", appName: "Slack")
        XCTAssertEqual(notice.title, "Slack")
        XCTAssertFalse(notice.body.isEmpty)
    }
}
