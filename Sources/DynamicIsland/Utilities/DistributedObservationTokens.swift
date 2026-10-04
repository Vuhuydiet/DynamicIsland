import Foundation

/// Owns the lifecycle of block-based `NotificationCenter` / `DistributedNotificationCenter`
/// observers.
///
/// ## Why this exists
///
/// Both `NotificationCenter.addObserver(forName:object:queue:using:)` and its
/// `DistributedNotificationCenter` counterpart return an **opaque token that must be
/// passed back to `removeObserver` to unregister**. That is a classic
/// retain-and-forget: the centre keeps the block alive until the token is removed, so
/// discarding it is only harmless while the registering type is a process-lifetime
/// singleton.
///
/// Every manager in this app *is* a singleton today, so the tokens were being thrown
/// away at all 15 call sites and nothing leaked. That made it a latent defect rather
/// than an active one — but "we are a singleton, so it is fine" is not a property the
/// type system or the compiler enforces, and the first extraction of a manager out of
/// the singleton graph would have turned it into a real leak with no warning.
///
/// This type makes the correct thing the short thing: one registrar that returns the
/// tokens as a value, and one removal call. A new observer is a single array entry,
/// and teardown is a single `deinit` line, so no call site can forget half of it
/// (AGENTS.md §1.1, level 3 — a single choke point every path passes through).
///
/// Note the distinction from the selector-based API used elsewhere in the app:
/// `addObserver(_:selector:name:object:)` with a *target* is unregistered
/// automatically when the target deallocates and needs no token. Only the
/// block-based form does. The two are mixed across this codebase, which is exactly
/// why the trap is easy to fall into.
public enum DistributedObservationTokens {

    /// Registers a block for each notification name and returns the tokens needed to
    /// unregister them.
    ///
    /// - Parameters:
    ///   - names: Notification names to observe, on `DistributedNotificationCenter`.
    ///   - handler: The block to invoke for any of them. It is the caller's
    ///     responsibility to capture weakly where it captures `self`.
    /// - Returns: One token per name, in the order the names were given. Pass the
    ///   whole array to `remove(_:)` to tear the set down.
    @discardableResult
    public static func observe(
        _ names: [String],
        center: DistributedNotificationCenter = .default(),
        queue: OperationQueue? = .main,
        handler: @escaping (Notification) -> Void
    ) -> [any NSObjectProtocol] {
        names.map { name in
            center.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: queue,
                using: handler
            )
        }
    }

    /// Typed convenience for a name → handler map, which is the shape almost every
    /// call site in the app actually wants.
    @discardableResult
    public static func observe(
        _ handlersByName: [String: (Notification) -> Void],
        center: DistributedNotificationCenter = .default(),
        queue: OperationQueue? = .main
    ) -> [any NSObjectProtocol] {
        handlersByName.map { name, handler in
            center.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: queue,
                using: handler
            )
        }
    }

    /// Unregisters every token in `tokens`. Safe to call more than once, and safe
    /// with an empty array, so `deinit` does not need to know whether `setup()` ran.
    public static func remove(_ tokens: [any NSObjectProtocol]) {
        for token in tokens {
            DistributedNotificationCenter.default().removeObserver(token)
        }
    }
}
