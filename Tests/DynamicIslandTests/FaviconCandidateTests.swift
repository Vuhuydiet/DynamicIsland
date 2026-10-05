import XCTest
import AppKit
@testable import DynamicIsland

/// Guards the pure half of favicon resolution: which URLs we would try, and which
/// representation of a decoded image we are willing to use.
///
/// Both rules are pure functions of their parameters, so what the user ends up seeing
/// in a tab is verifiable without a network or a window server (AGENTS.md §3).
final class FaviconCandidateTests: XCTestCase {

    // MARK: - Candidates

    func testCandidatesAreFaviconThenAppleTouchIcon() throws {
        let urls = FaviconFetcher.candidates(for: URL(string: "https://www.messenger.com/")!)
        XCTAssertEqual(urls.map(\.absoluteString), [
            "https://www.messenger.com/favicon.ico",
            "https://www.messenger.com/apple-touch-icon.png"
        ])
    }

    /// The icon is derived from the *host*, so a deep link must not lose the site.
    func testCandidatesIgnorePathQueryAndFragment() throws {
        let urls = FaviconFetcher.candidates(for: URL(string: "https://web.whatsapp.com/a/b?q=1#top")!)
        XCTAssertEqual(urls.map(\.absoluteString), [
            "https://web.whatsapp.com/favicon.ico",
            "https://web.whatsapp.com/apple-touch-icon.png"
        ])
    }

    func testCandidatesPreserveNonDefaultPort() throws {
        let urls = FaviconFetcher.candidates(for: URL(string: "http://localhost:8080/chat")!)
        XCTAssertEqual(urls.map(\.absoluteString), [
            "http://localhost:8080/favicon.ico",
            "http://localhost:8080/apple-touch-icon.png"
        ])
    }

    /// ATS is configured with `NSAllowsArbitraryLoads`, so nothing upstream stops a
    /// non-web scheme from reaching the fetcher. It has to be refused here.
    func testNonHTTPSchemeYieldsNoCandidates() throws {
        XCTAssertTrue(FaviconFetcher.candidates(for: URL(string: "ftp://files.example.com/")!).isEmpty)
        XCTAssertTrue(FaviconFetcher.candidates(for: URL(string: "file:///etc/passwd")!).isEmpty)
    }

    func testURLWithoutHostYieldsNoCandidates() {
        XCTAssertTrue(FaviconFetcher.candidates(for: URL(string: "https:///nohost")!).isEmpty)
    }

    // MARK: - Representation selection

    private func rep(_ w: Int, _ h: Int) -> NSBitmapImageRep {
        NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                         isPlanar: false, colorSpaceName: .deviceRGB,
                         bytesPerRow: w * 4, bitsPerPixel: 32)!
    }

    /// The real shape of a multi-image ICO, as bytes.
    ///
    /// The 0×0 representation is the whole hazard here, and it cannot be built by
    /// hand: `NSBitmapImageRep` refuses to construct one, returning `nil`. Only
    /// decoding an actual ICO produces it, so the fixture has to be a real ICO or the
    /// test is asserting against a shape the guard never actually meets.
    private func multiSizeICO() throws -> NSImage {
        try XCTUnwrap(NSImage(data: Self.multiSizeICOData))
    }

    /// A real multi-size ICO, embedded as bytes.
    ///
    /// The 0×0 representation is the entire hazard this rule guards against, and it
    /// *cannot* be constructed by hand — `NSBitmapImageRep` refuses to build one and
    /// returns `nil`. Only decoding an actual ICO produces it, so a synthetic
    /// fixture cannot test the case that matters: a test built from hand-made reps
    /// passes while the real failure goes uncaught.
    ///
    /// This is a two-entry PNG-in-ICO (32×32 and 16×16), which ImageIO decodes into
    /// one usable representation plus one 0×0 representation. Embedded rather than
    /// assembled at runtime because a hand-rolled encoder here is a second source of
    /// truth about the format, and getting it subtly wrong fails as "could not
    /// decode" — which looks like a bug in the code under test rather than in the
    /// fixture.
    private static let multiSizeICOData = Data(base64Encoded: """
        AAACAAIAICAAAAEAIABjAAAAFgAAABAQAAABACAAUQAAACYAAACJUE5HDQoaCgAAAA1JSERSAAAAIAAAAC\
        AIBgAAAHN6evQAAAAqSURBVHic7c4hAQAAAAIg/5/WGRYCnSTtl4CAgICAgICAgICAgICAwDkwW5X4\
        at1Sx2wAAAAASUVORK5CYIKJUE5HDQoaCgAAAA1JSERSAAAAEAAAABAIBgAAAB/z/2EAAAAYSURB\
        VHicY2Bg+P+fMjxqwKgBowYMEwMAMqb+EOW15KsAAAAASUVORK5CYII=
        """)!

    /// The measured failure this whole rule exists for: a genuine multi-image ICO
    /// decodes into a usable rep *plus* a 0×0 rep. Selecting on size alone picks the
    /// 0×0 and the tab renders an empty square.
    func testRealMultiSizeICODecodesWithADegenerateRep() throws {
        let image = try multiSizeICO()
        let bitmapReps = image.representations.compactMap { $0 as? NSBitmapImageRep }
        XCTAssertTrue(
            bitmapReps.contains { $0.pixelsWide == 0 },
            "fixture no longer reproduces the 0x0 rep; the test is no longer testing the real case"
        )
    }

    func testBestRepresentationSkipsZeroSizedReps() throws {
        let best = FaviconFetcher.bestRepresentation(in: try multiSizeICO())
        XCTAssertNotNil(best)
        XCTAssertGreaterThan(best?.pixelsWide ?? 0, 0, "must skip the 0x0 rep")
    }

    func testBestRepresentationPrefersLargest() {
        let image = NSImage(size: NSSize(width: 180, height: 180))
        image.addRepresentation(rep(16, 16))
        image.addRepresentation(rep(180, 180))

        XCTAssertEqual(FaviconFetcher.bestRepresentation(in: image)?.pixelsWide, 180)
    }

    /// Favicons are square, but a malformed file need not be — comparing area rather
    /// than width alone keeps a 512×8 strip from beating a 64×64 icon.
    func testBestRepresentationComparesAreaNotJustWidth() {
        let image = NSImage(size: NSSize(width: 512, height: 8))
        image.addRepresentation(rep(64, 64))
        image.addRepresentation(rep(512, 8))

        XCTAssertEqual(FaviconFetcher.bestRepresentation(in: image)?.pixelsWide, 64)
    }

    func testBestRepresentationOnEmptyImageIsNil() {
        XCTAssertNil(FaviconFetcher.bestRepresentation(in: NSImage(size: NSSize(width: 16, height: 16))))
    }

    /// An image whose only representation is degenerate must be rejected, not cached
    /// as a blank square.
    func testBestRepresentationOnOnlyDegenerateRepsIsNil() throws {
        let image = try XCTUnwrap(NSImage(data: Self.multiSizeICOData))
        let stripped = NSImage(size: NSSize(width: 1, height: 1))
        for representation in image.representations where representation.pixelsWide == 0 {
            stripped.addRepresentation(representation)
        }
        XCTAssertNil(FaviconFetcher.bestRepresentation(in: stripped))
    }

    /// The cached icon must be an image with real pixel data, not a zero-representation
    /// placeholder. `NSImage(size:)` has zero representations and `tiffRepresentation`
    /// is `nil` for it, so `saveIcon` would write nothing and the tab would keep its
    /// globe forever — with nothing indicating a failure.
    func testImageFromRepresentationIsActuallyEncodable() throws {
        let rep = try XCTUnwrap(FaviconFetcher.bestRepresentation(in: try multiSizeICO()))
        let rebuilt = FaviconFetcher.image(from: rep)

        XCTAssertEqual(rebuilt.representations.count, 1)
        XCTAssertNotNil(rebuilt.tiffRepresentation, "a rebuilt icon must survive saveIcon's TIFF step")
    }
}

