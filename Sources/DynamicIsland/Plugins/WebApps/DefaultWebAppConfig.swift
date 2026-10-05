import Foundation

/// The web apps seeded on first launch, read from a bundled JSON resource.
///
/// The list is data rather than Swift literals so that adding a default is a resource
/// edit, not a code change and a rebuild — and so the list of "apps we ship" is
/// reviewable as data by whoever maintains it.
///
/// ## Seeding is first-launch-only
///
/// This is read once, by `WebAppStore`, and only when its seed flag is unset.
/// Shipping a new default later therefore reaches *new* installs only: an existing
/// user who already has the flag set never receives it, and one who deliberately
/// deleted a default does not get it back. The alternative — re-reading on every
/// launch — makes deletion impossible, which is the worse failure.
public enum DefaultWebAppConfig {

    public static let resourceName = "DefaultWebApps"

    /// Bytes in, descriptors out. Never throws.
    ///
    /// Returns the entries it can trust and drops the ones it cannot, because the
    /// file is hand-edited and one bad entry should not cost the user every other
    /// default. A document that is not a JSON array yields an empty list: an absent
    /// or broken config is an honest empty state, not a crash and not a guess
    /// (docs/DESIGN.md §6, §7).
    ///
    /// Entries are re-serialised and decoded one at a time so that a single malformed
    /// entry throws inside its own `init(from:)` and is skipped, rather than taking
    /// the whole array down with it. `WebAppDescriptor.init(from:)` is what rejects
    /// an unrecognised key, so the strictness is defined in one place.
    public static func decode(_ data: Data) -> [WebAppDescriptor] {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let entries = object as? [Any] else { return [] }

        let decoder = JSONDecoder()
        return entries.compactMap { entry in
            guard JSONSerialization.isValidJSONObject(entry),
                  let element = try? JSONSerialization.data(withJSONObject: entry) else { return nil }
            return try? decoder.decode(WebAppDescriptor.self, from: element)
        }
    }

    /// Reads the resource from the app bundle.
    ///
    /// A thin wrapper on purpose: anything touching `Bundle` cannot run in the
    /// headless test target, so the logic lives in `decode` and this stays a
    /// two-liner (AGENTS.md §3).
    public static func loadFromBundle() -> [WebAppDescriptor] {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return decode(data)
    }
}
