import Testing
import Foundation
@testable import DynamicIsland

// MARK: - Right ear: the "graphical only, battery excepted" contract
//
// `RightEarToken` exists so that text cannot leak into the closed-notch right ear —
// see the long rationale in `RightEarPolicy.swift`. The *type* does the enforcing
// (AGENTS.md §1.1 level 1), but the claims that the type actually holds were only
// ever asserted in `#if DEBUG` blocks, and `build_app.sh` compiles with no `-D DEBUG`
// and no `-swift-version` flag — so in the shipping app those blocks are removed
// entirely and the assertions never run.
//
// The type is `Equatable`, `Sendable`, and free of any AppKit or SwiftUI runtime
// dependency, which makes it a pure headless test subject. These tests are the guard
// that `AGENTS.md` §1.1 asks for at level 4 (fails the build) instead of level 5
// (evidence only).

@Suite("Right ear: text-free token contract")
struct RightEarTokenTests {

    @Test("Battery is the only text-bearing token")
    func batteryIsTheOnlyTextBearingToken() {
        // Every case except `battery` must be non-text. Exhaustively enumerate them
        // so that adding a NEW case to `RightEarToken` fails to compile here until
        // someone has explicitly decided whether it carries text.
        let graphical: [RightEarToken] = [
            .mediaVisualizer,
            .mediaPauseGlyph,
            .timerProgressRing,
            .timerDonePulse,
            .stopwatchLapFlag,
            .stopwatchStateDot,
            .dropShelfGlyph,
            .pluginIcon(systemName: "bell.fill"),
            .notificationIcon(systemName: "message.fill"),
        ]
        for token in graphical {
            #expect(token.isTextBearing == false, "\(token) must not carry text")
            #expect(RightEarPolicy.violationDescription(for: token) == nil)
        }
        #expect(RightEarToken.battery.isTextBearing == true)
    }

    @Test("A blank icon symbol is rejected rather than rendered as a mystery box")
    func blankSymbolIsRejected() {
        // `Image(systemName: "")` renders a placeholder box in the notch. The policy
        // treats a blank symbol as a contract violation and degrades to `.battery`.
        let blank = RightEarToken.pluginIcon(systemName: "")
        #expect(RightEarPolicy.violationDescription(for: blank) != nil)
        #expect(RightEarPolicy.sanitized(blank) == nil)
        #expect(RightEarPolicy.token(for: blank) == .battery)
    }

    @Test("A whitespace-only icon symbol is rejected too")
    func whitespaceSymbolIsRejected() {
        // Guards the `trimmingCharacters` call specifically: without it, `"   "` is
        // a non-empty string and would sail through the `isEmpty` check.
        let padded = RightEarToken.notificationIcon(systemName: "   \n  ")
        #expect(RightEarPolicy.violationDescription(for: padded) != nil)
        #expect(RightEarPolicy.sanitized(padded) == nil)
    }

    @Test("A valid icon symbol passes through unchanged")
    func validSymbolIsPreserved() {
        let valid = RightEarToken.pluginIcon(systemName: "bubble.left.fill")
        #expect(RightEarPolicy.sanitized(valid) == valid)
        #expect(RightEarPolicy.violationDescription(for: valid) == nil)
    }

    @Test("No token ever degrades to anything other than the battery fallback")
    func fallbackIsAlwaysBattery() {
        // The fallback is what makes a malformed token safe rather than leaking
        // content, so it must be `.battery` and nothing else.
        #expect(RightEarPolicy.token(for: nil) == .battery)
        #expect(RightEarPolicy.sanitized(nil) == nil)
        // Sanitising a compliant token must be an identity function, so the policy
        // can never silently substitute a different appearance.
        for token in [RightEarToken.battery, .mediaVisualizer, .timerProgressRing] {
            #expect(RightEarPolicy.token(for: token) == token)
        }
    }
}
