import AppKit
import Foundation

/// Resolves a web app's tab icon from the site it points at.
///
/// A web app's identity is its site, and a generic globe on every tab makes the strip
/// unreadable as soon as there is more than one app. The icon is *derived* from the
/// URL rather than stored beside it, because it is mechanically derivable and a
/// hand-maintained copy could only ever disagree with the URL it describes.
///
/// Nothing fetched here is trusted: the response is remote, unauthenticated, and
/// frequently an HTML error page served under an image filename. A failure is not an
/// error state the user has to see — it means the tab keeps its globe (docs/DESIGN.md §6).
public enum FaviconFetcher {

    /// Paths tried in order; the first decodable response wins.
    ///
    /// `apple-touch-icon.png` is the second choice because it is the one icon most real
    /// sites keep at high resolution, while `/favicon.ico` is frequently a 16×16 legacy
    /// file. No third-party favicon service is used: a first-party path exists, so
    /// putting an undocumented external endpoint in the critical path of a cosmetic
    /// feature is a dependency the app does not need (docs/DESIGN.md §7).
    static let candidatePaths = ["favicon.ico", "apple-touch-icon.png"]

    /// Ceiling on a response body. A favicon is a small raster; anything larger is
    /// not one, and an unbounded read is how a hostile host turns a cosmetic feature
    /// into an allocation problem.
    static let maxIconBytes = 512 * 1024

    /// Per-request timeout. Short on purpose: this runs while the user is looking at a
    /// tab, and an icon that arrives after they stopped expecting it is noise.
    static let timeout: TimeInterval = 3

    // MARK: - Pure rules

    /// The URLs to try, in order. Empty unless the URL is an http(s) URL with a host.
    ///
    /// Rejecting other schemes is explicit rather than inherited: ATS is configured
    /// with `NSAllowsArbitraryLoads`, so nothing else would stop a `file:` or `ftp:`
    /// URL from reaching a network request.
    public static func candidates(for url: URL) -> [URL] {
        guard let scheme = url.scheme?.lowercased(),
              WebAppDescriptor.supportedSchemes.contains(scheme),
              let host = url.host, !host.isEmpty else { return [] }

        return candidatePaths.compactMap { path in
            var components = URLComponents()
            components.scheme = scheme
            components.host = host
            components.port = url.port
            components.path = "/" + path
            return components.url
        }
    }

    /// The largest usable representation, ignoring degenerate ones.
    ///
    /// A multi-image ICO can decode into a valid rep *and* a 0×0 rep. Comparing size
    /// alone would pick the 0×0 and the tab would render an empty square, so the zero
    /// case is excluded outright rather than merely losing a comparison. Area is
    /// compared rather than width because a malformed file need not be square.
    public static func bestRepresentation(in image: NSImage) -> NSBitmapImageRep? {
        // `representations` is `[NSImageRep]`; the typed accessor is what makes the
        // pixel dimensions available, and they are the whole point of the filter.
        image.representations
            .compactMap { $0 as? NSBitmapImageRep }
            .filter { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }
            .max { ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh) }
    }

    /// Rebuilds an image containing exactly the chosen representation.
    ///
    /// `NSImage(size:)` must not be used for this: it creates an image with *zero*
    /// representations, so its `tiffRepresentation` is `nil`, and `PluginIconManager
    /// .saveIcon` then returns early and writes nothing at all — the icon would
    /// silently never appear.
    static func image(from rep: NSBitmapImageRep) -> NSImage {
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }

    // MARK: - Fetching

    /// Fetches and caches the icon for `descriptor`, unless one is already present.
    ///
    /// The `hasIcon` guard is load-bearing rather than an optimisation: it resolves
    /// the disk cache *and* the app bundle, so the shipped Messenger icon satisfies
    /// it. Without the guard, every launch would re-fetch and replace a known-good
    /// bundled icon with whatever the network happened to return that day.
    ///
    /// Fire-and-forget by design. It runs at registration so the icon is correct
    /// before the user has opened the tab, and it must never delay first paint, so
    /// there is no synchronous path and no error surfaced to the UI.
    public static func fetchIfAbsent(
        for descriptor: WebAppDescriptor,
        into icons: PluginIconManager = .shared,
        session: URLSession = .shared
    ) {
        guard !icons.hasIcon(for: descriptor.id) else { return }

        let urls = candidates(for: descriptor.url)
        guard !urls.isEmpty else { return }

        tryFirst(urls, using: session) { rep in
            guard let rep else { return }
            icons.saveIcon(image: image(from: rep), for: descriptor.id)
        }
    }

    /// Tries each candidate in order, stopping at the first decodable image.
    ///
    /// Sequential rather than concurrent: the second request is only worth making once
    /// the first has failed, so firing both would put a request on the network whose
    /// answer is already known to be unwanted.
    private static func tryFirst(
        _ urls: [URL],
        using session: URLSession,
        completion: @escaping (NSBitmapImageRep?) -> Void
    ) {
        guard let next = urls.first else { return completion(nil) }
        let remaining = Array(urls.dropFirst())

        var request = URLRequest(url: next)
        request.timeoutInterval = timeout
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        session.dataTask(with: request) { data, response, _ in
            // Re-checked *after* redirects, not just on the URL we asked for: a host
            // can answer a request for /favicon.ico with a 302 to `file:` or `data:`,
            // and the body that follows is then not an icon at all.
            if let final = response?.url,
               let scheme = final.scheme?.lowercased(),
               !WebAppDescriptor.supportedSchemes.contains(scheme) {
                return tryFirst(remaining, using: session, completion: completion)
            }

            let rep = data
                .flatMap { $0.count <= maxIconBytes ? $0 : nil }
                .flatMap { NSImage(data: $0) }
                .flatMap { bestRepresentation(in: $0) }

            if let rep {
                // `saveIcon` publishes through `objectWillChange`, so it belongs on
                // the main thread; the fetch itself stays off it.
                DispatchQueue.main.async { completion(rep) }
            } else {
                tryFirst(remaining, using: session, completion: completion)
            }
        }.resume()
    }
}
