import Testing
import Foundation
@testable import DynamicIsland

// MARK: - Desktop media adapter parsing
//
// The four direct-query adapters (Music, Spotify, QuickTime, VLC) were four
// near-identical methods whose parsing was inline and therefore untested. The part
// most likely to be wrong quietly is the parsing: field order, unit conversion, and
// the two different state vocabularies ("playing"/"paused" for the music apps,
// "true"/"false" for the document players).
//
// A bug here is invisible until someone plays a track in that app and the island
// reports the wrong time or the wrong state — so the table is written out longhand
// and the unit conversions are checked explicitly.

@Suite("Desktop media app parsing")
struct DesktopMediaAppTests {

    /// Builds a delimited row exactly the way the AppleScript does: fields joined by
    /// `& "|||" &`.
    ///
    /// This helper exists because hand-written pipe literals are a demonstrated
    /// failure mode in this file. `"playing|||||Album"` looks like a blank field
    /// between two delimiters, but five pipes is *one* delimiter plus a stray `|`,
    /// so it splits as `["playing", "||Album", ...]` — one field short, with a
    /// corrupted artist. Such a fixture does not fail loudly; it silently asserts
    /// the wrong thing, which is worse than no test. Concatenating the same terms
    /// the script concatenates cannot be miscounted.
    private func row(_ fields: String...) -> String {
        fields.joined(separator: DesktopMediaApp.PIPE_DELIMITER)
    }

    // MARK: Identity invariants

    @Test("Bundle identifiers and sources are unique across apps")
    func identityIsUnambiguous() {
        let ids = DesktopMediaApp.allCases.map(\.bundleIdentifier)
        #expect(Set(ids).count == ids.count, "duplicate bundle id: \(ids)")
        // No app may claim another's source, or the accent colour and icon lie.
        #expect(Set(DesktopMediaApp.allCases.map(\.source)).count == DesktopMediaApp.allCases.count)
    }

    @Test("Only Spotify reports duration in milliseconds")
    func durationScaleIsCorrect() {
        // This is the invariant that was previously invisible: a literal `/ 1000`
        // buried inside Spotify's AppleScript string, while every other app
        // reported seconds. A track 3 minutes long would have shown as 180000
        // seconds, or 0.18 of a second, with no error anywhere.
        #expect(DesktopMediaApp.spotify.durationScale == 0.001)
        for app in DesktopMediaApp.allCases where app != .spotify {
            #expect(app.durationScale == 1.0, "\(app) should report seconds")
        }
    }

    @Test("Only the music apps report an album; the document players carry a fixed label")
    func albumReportingIsCorrect() {
        #expect(DesktopMediaApp.music.fieldCount == 6)
        #expect(DesktopMediaApp.spotify.fieldCount == 6)
        #expect(DesktopMediaApp.quickTime.fieldCount == 4)
        #expect(DesktopMediaApp.vlc.fieldCount == 4)
        #expect(DesktopMediaApp.music.albumLabel == nil)
        #expect(DesktopMediaApp.quickTime.albumLabel == "Local Video")
        #expect(DesktopMediaApp.vlc.albumLabel == "Video / Audio")
    }

    @Test("Every app's script names itself, and no app's script names another")
    func scriptsAreSelfNamed() {
        // The app name is interpolated into `tell application "…"`. A script that
        // named the wrong app would query something entirely different and look like
        // a silent failure.
        for app in DesktopMediaApp.allCases {
            #expect(app.script.contains("tell application \"\(app.applicationName)\""),
                    "\(app)'s script does not address itself")
        }
    }

    // MARK: Music-shaped parsing (6 fields, reported artist + album)

    @Test("A Music response parses with all six fields in order")
    func musicParsesSixFields() {
        let output = "playing|||Test Song|||Test Artist|||Test Album|||12.5|||240.0"
        let track = DesktopMediaApp.parse(output: output, app: .music)
        #expect(track != nil)
        #expect(track?.title == "Test Song")
        #expect(track?.artist == "Test Artist")
        #expect(track?.album == "Test Album")
        #expect(track?.position == 12.5)
        #expect(track?.duration == 240.0)
        #expect(track?.isPlaying == true)
        #expect(track?.source == .music)
        #expect(track?.bundleIdentifier == "com.apple.Music")
    }

    @Test("A Spotify duration in milliseconds is converted to seconds")
    func spotifyConvertsMilliseconds() {
        // 240000 ms must become 240 s, not 240000 and not 240.
        let output = "playing|||Test Song|||Test Artist|||Test Album|||12.5|||240000.0"
        let track = DesktopMediaApp.parse(output: output, app: .spotify)
        #expect(track?.duration == 240.0)
        #expect(track?.source == .spotify)
        // Position is *not* scaled — only duration was in ms. A regression that
        // scaled both would make the elapsed time run 1000x too fast.
        #expect(track?.position == 12.5)
    }

    @Test("A paused state is read as not playing, in both vocabularies")
    func pausedIsNotPlaying() {
        #expect(DesktopMediaApp.parse(
            output: "paused|||S|||A|||B|||1.0|||2.0", app: .music
        )?.isPlaying == false)
        #expect(DesktopMediaApp.parse(
            output: "false|||Movie|||1.0|||2.0", app: .quickTime
        )?.isPlaying == false)
    }

    @Test("A document player reports true as playing")
    func documentPlayerTrueIsPlaying() {
        // QuickTime returns a boolean string, not "playing" — the old QuickTime
        // adapter only checked `contains("true")`, while Music only checked
        // `contains("playing")`. Both vocabularies must now be understood by both.
        let track = DesktopMediaApp.parse(
            output: "true|||A Movie|||3.0|||120.0", app: .quickTime
        )
        #expect(track?.isPlaying == true)
    }

    // MARK: Document-player parsing (4 fields, no reported artist/album)

    @Test("A QuickTime response fills artist and album from the app")
    func quickTimeFillsAppAttribution() {
        let track = DesktopMediaApp.parse(
            output: "true|||A Movie|||3.0|||120.0", app: .quickTime
        )
        #expect(track?.title == "A Movie")
        // No artist or album is reported by a document player, so the app names
        // itself. A blank row would be worse.
        #expect(track?.artist == "QuickTime Player")
        #expect(track?.album == "Local Video")
        #expect(track?.position == 3.0)
        #expect(track?.duration == 120.0)
    }

    @Test("A VLC response is always playing, because its script only runs when it is")
    func vlcIsAlwaysPlaying() {
        let track = DesktopMediaApp.parse(
            output: "playing|||clip.mp4|||0.0|||60.0", app: .vlc
        )
        #expect(track?.isPlaying == true)
        #expect(track?.artist == "VLC Media Player")
        #expect(track?.album == "Video / Audio")
        #expect(track?.source == .vlc)
    }

    // MARK: Fallbacks

    @Test("Blank title or artist falls back to the app's own name, without shifting fields")
    func blankFieldsFallBack() {
        // Built the way the script builds it — a chain of `& "|||" &` — rather than
        // as a hand-counted run of pipes. An earlier version of this file wrote
        // `"playing|||||Album"` and *failed*, because five pipes is one delimiter
        // plus a stray `|`: it parsed as four fields with the album read as
        // `"|Album"`. Counting pipes by eye does not work, and a literal like that
        // is a silent-wrong-answer generator. Concatenation is the only form that
        // cannot be miscounted.
        //
        // AppleScript emits 9 pipes here, which `components(separatedBy: "|||")`
        // splits into the 4 fields the script meant (verified with `osascript`).
        let music = DesktopMediaApp.parse(
            output: row("playing", "", "", "Album", "0", "100"), app: .music
        )
        #expect(music?.title == "Unknown Title")
        #expect(music?.artist == "Apple Music")   // reported artist was blank
        #expect(music?.album == "Album")
        // The important part: duration did not slide into position.
        #expect(music?.position == 0)
        #expect(music?.duration == 100)

        // "playing" & "|||" & "" & "|||" & "0.0" & "|||" & "60.0"  (VLC, blank title)
        let vlc = DesktopMediaApp.parse(output: row("playing", "", "0.0", "60.0"), app: .vlc)
        #expect(vlc?.title == "Media File")
        #expect(vlc?.position == 0.0)
        #expect(vlc?.duration == 60.0)
    }

    @Test("Field splitting treats a run of pipes as one delimiter with empty fields between")
    func fieldSplittingCollapsesDelimiterRuns() {
        // An empty field makes the script emit *consecutive* delimiters, so the
        // splitter must preserve the empty field rather than drop it — dropping it
        // would slide every later index up one and report duration as position.
        //
        // It is `components(separatedBy:)`, not a hand-rolled three-chars-at-a-time
        // loop: on every row captured from the real interpreter the two agree
        // exactly, so the hand-rolled version was pure risk with no benefit.
        #expect(DesktopMediaApp.fields(of: row("a", "b", "c")) == ["a", "b", "c"])
        #expect(DesktopMediaApp.fields(of: row("playing", "", "", "Album", "0", "100"))
            == ["playing", "", "", "Album", "0", "100"])
        // Edge behaviour: a trailing or leading delimiter yields an empty edge field.
        #expect(DesktopMediaApp.fields(of: row("a", "")) == ["a", ""])
        #expect(DesktopMediaApp.fields(of: row("", "a")) == ["", "a"])
        // A single or double pipe is NOT the delimiter and must not split.
        #expect(DesktopMediaApp.fields(of: "a||b") == ["a||b"])
        #expect(DesktopMediaApp.fields(of: "solo") == ["solo"])
    }

    // MARK: Rejection

    @Test("Stopped, empty, and truncated responses yield no track")
    func rejectsUnusableResponses() {
        // This is the guard against a silently-wrong track. A short row used to be
        // `guard parts.count >= 6 else { return nil }` inline; the point is that a
        // truncated response must never become a track with zeroed timings.
        #expect(DesktopMediaApp.parse(output: "stopped", app: .music) == nil)
        #expect(DesktopMediaApp.parse(output: "", app: .music) == nil)
        // 3 fields where 6 are required.
        #expect(DesktopMediaApp.parse(output: "playing|||Song", app: .music) == nil)
        // 6 fields where 4 are required is fine (extra data is tolerated), but 3
        // where 4 are required is not.
        #expect(DesktopMediaApp.parse(output: "playing|||Song|||1.0", app: .vlc) == nil)
    }

    @Test("Non-numeric timings degrade to zero rather than dropping the track")
    func nonNumericTimingsDegradeToZero() {
        // An app mid-seek can report something unparseable. Dropping the track
        // entirely would make the island flicker to "No Media Playing" mid-playback,
        // so the timings fall back to zero and the track still shows.
        let track = DesktopMediaApp.parse(
            output: "playing|||Song|||Artist|||Album|||not-a-number|||also-bad", app: .music
        )
        #expect(track != nil)
        #expect(track?.position == 0)
        #expect(track?.duration == 0)
    }

    // MARK: Playback controls

    @Test("Detection queries apps in the order the old tier chain used")
    func detectionOrderMatchesTheFormerTierChain() {
        // `refreshMedia` used to walk Music → Spotify → QuickTime → VLC in five
        // hand-written `if` blocks. It is now a single loop over `allCases`, which
        // makes the *declaration order of the enum* load-bearing: reordering the
        // cases silently reorders detection priority, and two apps playing at once
        // would report differently with no other visible change.
        //
        // This is the test that makes that dependency safe to carry.
        #expect(DesktopMediaApp.allCases == [.music, .spotify, .quickTime, .vlc])
    }

    @Test("Every control verb addresses its own app and no other")
    func controlVerbsAddressTheirOwnApp() {
        // The bug this pins: the verbs used to be inline literals in three separate
        // control methods, so a copy-paste that addressed Music while the branch was
        // meant for Spotify compiled fine, passed CI, and sent the command to the
        // wrong player. Each app's verbs must now name that app and only that app.
        for app in DesktopMediaApp.allCases {
            guard let controls = app.controls else { continue }
            let verbs = [controls.play, controls.pause, controls.next, controls.previous]
                .compactMap { $0 }
            #expect(!verbs.isEmpty, "\(app) has no control verbs at all")
            for verb in verbs {
                #expect(
                    verb.contains("\"\(app.applicationName)\""),
                    "\(app) has a verb that does not address it: \(verb)"
                )
                for other in DesktopMediaApp.allCases where other != app {
                    #expect(
                        !verb.contains("\"\(other.applicationName)\""),
                        "\(app)'s verb addresses \(other): \(verb)"
                    )
                }
            }
            #expect(controls.owner == app)
        }
    }

    @Test("Document players have no next/previous, because they have no playlist")
    func documentPlayersHaveNoTrackStepping() {
        // QuickTime plays documents, not a queue. The old control chain simply had
        // no branch for it, which read as an oversight; here it is a stated `nil`,
        // so the caller falls through to MediaRemote knowingly.
        let quickTime = DesktopMediaApp.quickTime.controls
        #expect(quickTime != nil)
        #expect(quickTime?.next == nil)
        #expect(quickTime?.previous == nil)
        // …but it does still play, pause, and seek.
        #expect(quickTime?.play != nil)
        #expect(quickTime?.pause != nil)
        #expect(quickTime?.setPosition(10) != nil)

        // The music apps are the opposite: a queue exists, so stepping must work.
        for app in [DesktopMediaApp.music, .spotify] {
            #expect(app.controls?.next != nil, "\(app) cannot skip tracks")
            #expect(app.controls?.previous != nil, "\(app) cannot go back")
        }
    }

    @Test("Only the document player guards its commands on having a document open")
    func onlyDocumentPlayerGuardsOnOpenDocuments() {
        // Pressing play with nothing loaded must be a no-op, not an error dialog.
        // QuickTime is the only adapter that needs this: it addresses `document 1`,
        // which does not exist when the app is closed.
        //
        // Unwrapped into locals first, deliberately. `controls?.play ?? ""` inside a
        // `.contains(...)` call parses as `controls?.(play ?? "")`, yielding
        // `Optional<Bool>` — and `!Optional<Bool>` is always `false`, so the
        // assertion below would pass no matter what the verbs contained.
        let quickTimePlay = DesktopMediaApp.quickTime.controls?.play ?? ""
        #expect(quickTimePlay.contains("count of documents"))
        let quickTimePause = DesktopMediaApp.quickTime.controls?.pause ?? ""
        #expect(quickTimePause.contains("count of documents"))

        // The music apps and VLC talk to the player directly and must not carry the
        // guard, which would be a wasted round-trip on every button press.
        for app in [DesktopMediaApp.music, .spotify, .vlc] {
            let play = app.controls?.play ?? ""
            #expect(!play.contains("count of documents"), "\(app) should not guard on documents")
        }
    }

    @Test("Seeking is offered only by apps that can seek, and embeds the target time")
    func seekIsOfferedOnlyWhereSupported() {
        // VLC can seek, but this path supplements a MediaRemote seek that already
        // covers it, so it stays off — matching the `switch` this replaced rather
        // than quietly widening behaviour.
        #expect(DesktopMediaApp.vlc.controls?.setPosition(42) == nil)

        for app in [DesktopMediaApp.music, .spotify, .quickTime] {
            let script = app.controls?.setPosition(42.5)
            #expect(script != nil, "\(app) should support seek")
            #expect(script?.contains("42.5") == true, "\(app) did not embed the time")
            #expect(script?.contains("\"\(app.applicationName)\"") == true)
        }
        // A fractional time must survive interpolation — a rounded or truncated
        // seek would land the scrubber in the wrong place.
        #expect(DesktopMediaApp.music.controls?.setPosition(0.25)?.contains("0.25") == true)
    }

    @Test("No control verb is blank, since a blank script is sent to the interpreter")
    func controlVerbsAreNonEmpty() {
        // A `""` would be executed as an empty script and report success while doing
        // nothing — the failure mode that made absence need to be `nil` rather than
        // empty string.
        for app in DesktopMediaApp.allCases {
            guard let controls = app.controls else { continue }
            #expect(!controls.play.isEmpty, "\(app) has a blank play verb")
            #expect(!controls.pause.isEmpty, "\(app) has a blank pause verb")
            if let next = controls.next { #expect(!next.isEmpty, "\(app) has a blank next verb") }
            if let previous = controls.previous {
                #expect(!previous.isEmpty, "\(app) has a blank previous verb")
            }
        }
    }
}
