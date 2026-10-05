import Foundation

// MARK: - Web App Descriptor
//
// The persisted unit for a user-added web app. This file is deliberately free of
// AppKit, SwiftUI, and every global: everything derivable from a descriptor is a
// pure function of its parameters, so the same code is both the validation the UI
// relies on and the surface the tests exercise (AGENTS.md §3).

/// A web app the user added, stored as plain data.
///
/// `id` is stable and is what `IslandTab` stores, what `PluginManager` registers
/// under, and what persisted sound overrides are keyed by — so it must not change
/// when the user edits the URL or renames the app.
public struct WebAppDescriptor: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var url: URL
    public var isEnabled: Bool

    public init(id: String, name: String, url: URL, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
    }

    /// A descriptor entry that cannot be trusted, reported rather than silently repaired.
    public enum DecodeError: Error, Equatable {
        /// Keys present in the JSON that this type does not declare.
        case unknownKeys([String])
    }

    public enum CodingKeys: String, CodingKey, CaseIterable {
        case id, name, url, isEnabled
    }

    /// Decodes strictly: an unrecognised key throws instead of being ignored.
    ///
    /// Swift's synthesised conformance silently drops unknown keys, which is fine for
    /// data the app wrote itself and wrong for `Resources/DefaultWebApps.json`, which a
    /// human edits. A misspelled `"isenable"` would otherwise produce a working app
    /// with a silently wrong field and no error anywhere — and since the same decoder
    /// reads the persisted list, the guard covers both paths at once.
    ///
    /// The declared set is derived from `allCases` rather than retyped, so adding a
    /// field to `CodingKeys` is all that is needed to keep this total (AGENTS.md §5).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Read through an untyped container on purpose. A `CodingKeys`-typed one
        // *filters out* keys it does not declare, so `allKeys` there can only ever
        // report what was already known — checking it would compare the declared
        // names against themselves and never fire. The untyped container is the only
        // view of the document that includes what the author actually wrote.
        let raw = try decoder.container(keyedBy: AnyCodingKey.self)
        let declared = Set(CodingKeys.allCases.map(\.rawValue))
        let unknown = raw.allKeys
            .map(\.stringValue)
            .filter { !declared.contains($0) }
            .sorted()
        guard unknown.isEmpty else {
            throw DecodeError.unknownKeys(unknown)
        }

        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.url = try container.decode(URL.self, forKey: .url)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

/// A `CodingKey` that accepts any string, so a decoder container can be asked what
/// keys a document *actually* contains instead of which ones the type expects.
///
/// This exists because a container keyed by a concrete `CodingKeys` enum hides
/// everything it does not declare, and strict decoding is precisely the act of
/// noticing those hidden keys. It is never used to read a value — only to enumerate.
struct AnyCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

// MARK: - URL Validation

/// The outcome of validating a user-typed URL.
///
/// A closed enum rather than a `URL?`, because every rejection is a distinct reason
/// the user needs to see. A bare optional would collapse "you typed nothing" and
/// "that isn't a web address" into one indistinguishable failure, and the next
/// branch added to the UI would be free to ignore the difference.
public enum WebAppURLParse: Equatable, Sendable {
    case valid(URL)
    case empty
    case notHTTP
    case noHost

    /// User-facing explanation, or `nil` when the parse succeeded.
    public var failureReason: String? {
        switch self {
        case .valid: return nil
        case .empty: return "Enter a web address."
        case .notHTTP: return "Only http and https addresses are supported."
        case .noHost: return "That address has no site name in it."
        }
    }

    public var url: URL? {
        if case .valid(let url) = self { return url }
        return nil
    }
}

public extension WebAppDescriptor {
    /// Schemes a web view can actually load. Anything else is rejected rather than
    /// handed to `WKWebView`, which would fail later with no explanation.
    static let supportedSchemes: Set<String> = ["http", "https"]

    /// Parses raw user input into a URL, tolerating a missing scheme.
    ///
    /// A user pasting `messenger.com` means `https://messenger.com`, so a bare host
    /// is upgraded rather than rejected. Everything else that fails to parse is
    /// reported through a specific case.
    static func parse(_ raw: String) -> WebAppURLParse {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        // Only default the scheme when the input has none of its own. Prefixing
        // blindly would turn `ftp://x` into `https://ftp://x`.
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"

        guard let components = URLComponents(string: candidate) else { return .noHost }

        let scheme = (components.scheme ?? "").lowercased()
        guard supportedSchemes.contains(scheme) else { return .notHTTP }

        guard let host = components.host, !host.isEmpty else { return .noHost }
        guard let url = components.url else { return .noHost }

        return .valid(url)
    }

    /// A stable reverse-DNS identifier derived from the URL.
    ///
    /// Derived from the host alone so that editing a path or adding a scheme leaves
    /// the identity — and therefore the tab, the icon, and the saved sound — intact.
    /// The `web.` infix distinguishes these from plugin ids.
    static func identifier(for url: URL) -> String {
        let host = (url.host ?? url.absoluteString)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = host
            .replacingOccurrences(of: "[^a-z0-9.-]", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        return "com.dynamicisland.webapp.web.\(sanitized)"
    }

    /// A readable label derived from the host, used when the user supplies no name.
    ///
    /// Messaging sites bury the brand in the host — `www.messenger.com`,
    /// `web.whatsapp.com` — so leading platform labels and the public suffix are both
    /// stripped, leaving the part a person would actually call the app. Falls back to
    /// progressively less trimming rather than returning an empty string.
    static func displayName(for url: URL) -> String {
        guard let host = url.host, !host.isEmpty else { return "Web App" }

        var labels = host.lowercased().split(separator: ".").map(String.init)

        // Leading platform labels, not brands: "web.whatsapp.com" is WhatsApp.
        let platformLabels: Set<String> = ["www", "web", "app", "m", "chat", "mail", "mobile"]
        while labels.count > 1, platformLabels.contains(labels[0]) {
            labels.removeFirst()
        }

        // Trailing public suffix: "messenger.com" -> "Messenger".
        if labels.count > 1, Self.publicSuffixes.contains(labels[labels.count - 1]) {
            labels.removeLast()
        }

        let joined = labels.joined(separator: " ")
        guard !joined.isEmpty else { return "Web App" }
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }

    private static let publicSuffixes: Set<String> = [
        "com", "net", "org", "io", "co", "app", "dev", "me", "ai", "sh", "tv", "gg",
    ]
}

// MARK: - Legacy identifiers

/// Identifiers that shipped before web apps were data-driven.
///
/// These are *not* the seed list — that lives in `Resources/DefaultWebApps.json`.
/// They are the handful of ids that are baked into other persisted state, and which
/// therefore cannot come from a file that a future edit could change: a tab order
/// saved under the old id, a sound override, a legacy `"Messenger"` tab label.
/// Reading one of these from the config would mean a change to that file could
/// silently orphan an upgrading user's saved state.
public enum WebAppLegacyID {
    /// The original Messenger plugin id.
    ///
    /// Kept as the exact string the shipped `PluginIcons/com.dynamicisland.plugin.messenger.png`
    /// resolves against and that persisted `pluginSoundOverrides` are keyed by.
    public static let messenger = "com.dynamicisland.plugin.messenger"
}

