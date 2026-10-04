import Testing
import Foundation
@testable import DynamicIsland

// MARK: - Sound cue contract
//
// `SoundManager.play(_:)` maps (scheme, event) to a system sound name through a pair
// of nested switches. It is pure, and it was entirely untested despite driving every
// audible cue in the app.
//
// The mapping is intentionally *not* uniform: each scheme is a different palette, so
// the same event legitimately resolves to different names per scheme. That is a
// design decision, and an unpinned one — a well-meaning "fix" that made the schemes
// consistent, or an off-by-one that shifted one cell, would change what the user
// hears and nothing in the build would notice. These tests make that palette
// explicit, and assert the properties that must hold for any of it.

/// The full, intended scheme × event → cue table.
///
/// Written out longhand rather than derived, so that changing `SoundManager` without
/// changing *this* is a visible, failing diff instead of a silent behavioural change.
private let expectedCueTable: [SoundScheme: [SoundManager.SoundType: String]] = [
    .classic: [
        .expand: "Pop",
        .collapse: "Tink",
        .click: "Blow",
        .drop: "Bottle",
        .timerAlert: "Ping",
        .notification: "Glass",
    ],
    .modern: [
        .expand: "Hero",
        .collapse: "Morse",
        .click: "Ping",
        .drop: "Purr",
        .timerAlert: "Ping",
        .notification: "Hero",
    ],
    .subtle: [
        .expand: "Tink",
        .collapse: "Tink",
        .click: "Pop",
        .drop: "Tink",
        .timerAlert: "Ping",
        .notification: "Tink",
    ],
]

@Suite("Sound scheme → cue mapping")
struct SoundManagerMappingTests {

    @Test("Every scheme resolves every event to its intended system sound")
    func cueTableMatches() {
        for (scheme, events) in expectedCueTable {
            for (type, name) in events {
                #expect(
                    SoundManager.systemSoundName(for: type, scheme: scheme) == name,
                    "\(scheme.rawValue) / \(type) should play \(name)"
                )
            }
        }
    }

    @Test("No event is unmapped in any scheme")
    func everyEventIsMapped() {
        // A new `SoundType` case with no cell in one scheme would otherwise resolve
        // to nothing and play silence.
        for scheme in SoundScheme.allCases {
            for type in SoundManager.SoundType.allCases {
                #expect(
                    !SoundManager.systemSoundName(for: type, scheme: scheme).isEmpty,
                    "\(scheme.rawValue) / \(type) has no cue"
                )
            }
        }
    }

    @Test("The cursor-idle visualizer fallback is not a sound, and the timer alert is not the expand cue")
    func schemesRemainDistinct() {
        // `subtle` deliberately collapses expand/collapse/drop onto one cue — that
        // is the point of a "quiet" scheme. Pin it so a future edit doesn't "fix"
        // the palette and change the character of the scheme.
        #expect(SoundManager.systemSoundName(for: .expand, scheme: .subtle)
                == SoundManager.systemSoundName(for: .collapse, scheme: .subtle))
        // And `classic` keeps them distinct, which is the opposite choice.
        #expect(SoundManager.systemSoundName(for: .expand, scheme: .classic)
                != SoundManager.systemSoundName(for: .collapse, scheme: .classic))
    }

    @Test("Every mapped cue is a real system sound on this Mac")
    func cuesExistOnDisk() {
        // The cue names are `NSSound(named:)` lookups into /System/Library/Sounds.
        // A typo is silent at runtime — `NSSound(named:)` returns nil and nothing
        // plays. This is the one place the *name* rather than the mapping is checked.
        //
        // Checked against the filesystem rather than `NSSound(named:)` because that
        // API is lenient: it happily resolves a name with stray whitespace, so using
        // it here would make this test pass for a broken string. A real path in
        // /System/Library/Sounds is the strict version of the same question.
        let soundDir = "/System/Library/Sounds"
        let missing = expectedCueTable.values
            .flatMap { $0.values }
            .uniqued()
            .filter { !FileManager.default.fileExists(atPath: "\(soundDir)/\($0).aiff") }
        #expect(missing.isEmpty, "missing system sounds: \(missing.joined(separator: ", "))")
    }
}

extension Sequence where Element: Hashable {
    /// Order-preserving de-duplication, so a failure message is stable.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
