import AppKit

// MARK: - Edit Shortcut Contract

/// Type-safe home for the two selector names AppKit declares only informally.
///
/// `undo:` and `redo:` are dispatched by `NSUndoManager` but are not declared in any
/// public header, so `#selector` cannot name them and a plain string would be a typo
/// that silently yields a dead menu item. Declaring them here in an `@objc` protocol
/// means the compiler still verifies the spelling, and the menu's selector is
/// derived from a real method rather than typed by hand.
@objc private protocol IslandUndoRedoSelectors {
    @objc func undo(_ sender: Any?)
    @objc func redo(_ sender: Any?)
}

/// Pure description of one text-editing shortcut the island guarantees.
///
/// Each case is a closed enum rather than a raw string selector, so a typo in a
/// selector name is a **compile error** and an accidental second owner of `⌘C` is
/// impossible to express (AGENTS.md §0.3, levels 1–2). The menu items are installed
/// with a **nil target**; that is deliberate, because AppKit then sends the action
/// down the responder chain to whatever is genuinely first responder — the
/// `NSTextView` backing a `TextEditor`, the `NSTextField` behind a `TextField`, or
/// the `WKWebView` inside a plugin tab. The island never implements copy/paste
/// itself; it only guarantees the combination is claimed by a menu and reaches the
/// responder.
public enum IslandEditAction: Equatable {
    case undo
    case redo
    case cut
    case copy
    case paste
    case delete
    case selectAll

    public var title: String {
        switch self {
        case .undo:      return "Undo"
        case .redo:      return "Redo"
        case .cut:       return "Cut"
        case .copy:      return "Copy"
        case .paste:     return "Paste"
        case .delete:    return "Delete"
        case .selectAll: return "Select All"
        }
    }

    /// Responder-chain action, resolved with `#selector` so a renamed or missing
    /// AppKit selector fails to build instead of producing a dead menu item.
    public var selector: Selector {
        switch self {
        case .undo:      return #selector(IslandUndoRedoSelectors.undo(_:))
        case .redo:      return #selector(IslandUndoRedoSelectors.redo(_:))
        case .cut:       return #selector(NSText.cut(_:))
        case .copy:      return #selector(NSText.copy(_:))
        case .paste:     return #selector(NSText.paste(_:))
        case .delete:    return #selector(NSText.delete(_:))
        case .selectAll: return #selector(NSText.selectAll(_:))
        }
    }

    /// `nil` means the item has no key equivalent (a menu-bar-only entry).
    public var keyEquivalent: String? {
        switch self {
        case .undo:      return "z"
        case .redo:      return "Z"
        case .cut:       return "x"
        case .copy:      return "c"
        case .paste:     return "v"
        case .delete:    return nil
        case .selectAll: return "a"
        }
    }

    public var modifiers: NSEvent.ModifierFlags {
        switch self {
        case .undo:      return .command
        case .redo:      return [.command, .shift]
        default:         return .command
        }
    }
}

// MARK: - IslandFocusController

/// The single owner of the island's keyboard focus and of the app's main menu.
///
/// ## Why this type exists
///
/// The island is an `LSUIElement` accessory hosted in a `.nonactivatingPanel` that is
/// shown with `orderFrontRegardless()`. That leaves two independent holes, and an
/// editing shortcut such as `⌘C` / `⌘V` is only fixed once *both* are closed:
///
/// 1. **No main menu.** AppKit does not deliver `⌘C`/`⌘V` to views as key events. It
///    offers the combination to the main menu via `NSMenu.performKeyEquivalent(_:)`,
///    and only reaches `copy(_:)`/`paste(_:)` on the first responder if some menu item
///    claims it. The bundle declares no `NSMainNibFile` and nothing else ever assigns
///    `NSApp.mainMenu`, so it is `nil` for the whole process lifetime and the
///    combination falls through — the island receives a literal `c` / `v` instead.
/// 2. **Never key.** `orderFrontRegardless()` explicitly does *not* make the window
///    key, and a non-activating panel does not take key status on click. So even with
///    a menu installed there is no first responder for `copy(_:)` to act on, and a
///    `WKWebView` in a plugin tab never receives web focus — which is why typing and
///    pasting "worked" in some tabs by accident (a `TextField` grabbing first responder
///    some other way) and not in others.
///
/// Fixing either one alone leaves the bug intact, which is why both live here behind
/// a single choke point rather than at the individual call sites that need them.
public final class IslandFocusController: NSObject {
    public static let shared = IslandFocusController()

    private var installedMenu: NSMenu?

    private override init() {
        super.init()
    }

    // MARK: Edit shortcut contract

    /// The shortcuts the island guarantees to every text-editing surface, plugin
    /// tabs included. Exposed as a pure value so the contract can be asserted
    /// directly, without launching the app or building a menu.
    public static let editActions: [IslandEditAction] = [
        .undo, .redo, .cut, .copy, .paste, .selectAll,
    ]

    /// Pure validator: returns the actions whose key equivalent collides with
    /// another's. AppKit resolves a matching key equivalent to whichever item it
    /// finds first, so a duplicate silently makes one of them dead — exactly the bug
    /// class this type exists to prevent, so it is checked rather than assumed.
    public static func duplicateKeyEquivalents(
        _ actions: [IslandEditAction] = editActions
    ) -> [IslandEditAction] {
        var seen: Set<String> = []
        var duplicates: Set<IslandEditAction> = []
        for action in actions {
            guard let key = action.keyEquivalent else { continue }
            // "Z" and "z" are the same physical combination (⇧⌘Z).
            let normalized = key.lowercased() + ":" + String(action.modifiers.rawValue)
            if seen.contains(normalized) {
                duplicates.insert(action)
            } else {
                seen.insert(normalized)
            }
        }
        return Array(duplicates)
    }

    // MARK: Main menu

    /// Installs the app's main menu. Idempotent, so repeated `setup()` calls or a
    /// screen change cannot stack duplicate menus.
    public func installMainMenu() {
        guard installedMenu == nil else { return }

        #if DEBUG
        let dupes = Self.duplicateKeyEquivalents()
        assert(dupes.isEmpty, """
            IslandFocusController.installMainMenu(): two edit actions claim the same \
            key equivalent (\(dupes.map(\.title))). AppKit would make one of them \
            unreachable.
            """)
        #endif

        let menu = buildMainMenu()
        NSApp.mainMenu = menu
        installedMenu = menu
    }

    private func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // ── Application menu ────────────────────────────────────────────────
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Dynamic Island")
        appMenu.addItem(
            withTitle: "About Dynamic Island",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())

        // Plain ⌘, is owned by this menu item. The local key monitor in
        // WindowController deliberately only claims the Option+⌘, variant, so each
        // combination keeps exactly one owner.
        let preferences = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        preferences.target = self
        appMenu.addItem(preferences)
        appMenu.addItem(.separator())

        appMenu.addItem(
            withTitle: "Quit Dynamic Island",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // ── Edit menu ───────────────────────────────────────────────────────
        // This is the menu that makes ⌘C / ⌘V / ⌘Z work at all: AppKit matches the
        // key equivalent here, then routes the action to the first responder.
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")

        for action in Self.editActions {
            let item = NSMenuItem(title: action.title, action: action.selector, keyEquivalent: "")
            item.keyEquivalentModifierMask = action.modifiers
            if let key = action.keyEquivalent {
                item.keyEquivalent = key
            }
            // `target` stays nil on purpose — see IslandEditAction's doc comment.
            editMenu.addItem(item)
        }

        editMenu.addItem(.separator())
        editMenu.addItem(
            NSMenuItem(title: IslandEditAction.delete.title, action: IslandEditAction.delete.selector, keyEquivalent: "")
        )

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        return mainMenu
    }

    @objc private func openPreferences() {
        SettingsWindowController.shared.show()
    }

    // MARK: Key window & activation

    /// Called when the user presses inside the island.
    ///
    /// `makeKey()` runs synchronously so the responder chain is already correct for
    /// the very click that triggered it, while activation is deferred by one runloop
    /// turn so that activating the app cannot swallow the click still in flight.
    public func islandDidReceiveClick() {
        WindowController.shared.panel?.makeKey()
        DispatchQueue.main.async { [weak self] in
            self?.activateForTyping()
        }
    }

    /// A non-activating panel does not take key status on click, and key events only
    /// reach the *active* application, so typing requires an explicit activation.
    /// This is deliberately lazy — it happens on a click, never on hover, so merely
    /// passing the cursor over the notch never steals the user's keyboard.
    private func activateForTyping() {
        guard !NSApp.isActive else { return }
        NSApp.activate()
        // Re-assert key status: activation can hand key back to another window.
        WindowController.shared.panel?.makeKey()
    }

    /// Hands focus back once the island has closed, so the app the user was working
    /// in regains the keyboard without a manual app switch.
    public func resignFocusIfIdle() {
        guard !AppState.shared.isPinned, !AppState.shared.isExpanded else { return }
        WindowController.shared.panel?.resignKey()
        // Never yank focus away while the Settings window is on screen.
        guard SettingsWindowController.shared.window?.isVisible != true else { return }
        guard NSApp.isActive else { return }
        NSApp.deactivate()
    }
}
