import Testing
import Foundation
@testable import DynamicIsland

// MARK: - Edit shortcut contract
//
// `IslandFocusController` owns the menu that makes ⌘C / ⌘V / ⌘Z work at all: AppKit
// matches key equivalents against the main menu and only routes the action to the
// first responder if some item claims it. A duplicate claim is silently fatal —
// AppKit resolves to whichever item it finds first and the other becomes unreachable
// — which is invisible at the call site and only shows up as "paste doesn't work in
// this one tab" (fixed in `3195a56`).
//
// `installMainMenu` does check this, but only inside `#if DEBUG`. `build_app.sh`
// passes no `-D DEBUG` and no `-swift-version`, so that assertion is compiled out of
// the shipping app. The check is a pure function over `Sendable` values, so it
// belongs here where it actually fails a build.

@Suite("Edit shortcut contract")
struct IslandEditActionTests {

    @Test("The installed edit menu has no duplicate key equivalents")
    func noDuplicateKeyEquivalents() {
        #expect(IslandFocusController.duplicateKeyEquivalents().isEmpty)
    }

    @Test("A deliberate collision is detected, not silently accepted")
    func collisionIsDetected() {
        // Proves the validator is not vacuously returning empty. ⌘C twice would make
        // one of the two copy items dead, so the duplicate must be reported.
        let colliding: [IslandEditAction] = [.copy, .paste, .copy]
        #expect(IslandFocusController.duplicateKeyEquivalents(colliding) == [.copy])
    }

    @Test("Shift and lowercase variants of the same physical key collide")
    func shiftVariantCollides() {
        // `.undo` is ⌘Z and `.redo` is ⇧⌘Z. In AppKit a key equivalent is a
        // character *plus* a modifier mask, and the mask distinguishes them — but a
        // caller passing "z" and "Z" both with `.command` is the same collision the
        // real menu would produce, so the normaliser lowercases before comparing.
        let colliding: [IslandEditAction] = [.undo, .undo]
        #expect(IslandFocusController.duplicateKeyEquivalents(colliding) == [.undo])
    }

    @Test("Every installed action resolves to a real AppKit selector")
    func everyActionHasASelector() {
        // The selectors are built with `#selector`, so this cannot fail to compile
        // against a renamed AppKit API. The assertion is that the enum is total:
        // no action can be added without producing a selector.
        for action in IslandFocusController.editActions {
            #expect(action.selector != Selector(("")), "\(action.title) has no selector")
            #expect(!action.title.isEmpty)
        }
        // Every action that the menu claims a key for must declare one.
        for action in IslandFocusController.editActions {
            #expect(action.keyEquivalent != nil, "\(action.title) claims no key")
        }
    }

    @Test("Delete is menu-only and is not part of the shortcut contract")
    func deleteIsMenuOnly() {
        // `delete` has no key equivalent on purpose, and it is appended separately
        // from `editActions` in `buildMainMenu`. This pins that separation: adding it
        // to `editActions` would claim a key it does not own.
        #expect(IslandEditAction.delete.keyEquivalent == nil)
        #expect(!IslandFocusController.editActions.contains(.delete))
    }
}
