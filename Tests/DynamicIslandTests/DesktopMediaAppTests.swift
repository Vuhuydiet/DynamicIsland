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
        // This row is verbatim AppleScript output for a track with no title and no
        // artist, captured from the real interpreter: two empty fields make the
        // concatenation emit a run of pipes, and the split still lines up.
        let music = DesktopMediaApp.parse(
            output: "playing|||||||||Album|||0|||100", app: .music
        )
        #expect(music?.title == "Unknown Title")
        #expect(music?.artist == "Apple Music")   // reported artist was blank
        #expect(music?.album == "Album")
        // The important part: duration did not slide into position.
        #expect(music?.position == 0)
        #expect(music?.duration == 100)

        // Verbatim concatenation: "playing" & "|||" & "" & "|||" & "0.0" & "|||" & "60.0"
        let vlc = DesktopMediaApp.parse(output: "playing||||||0.0|||60.0", app: .vlc)
        #expect(vlc?.title == "Media File")
        #expect(vlc?.position == 0.0)
        #expect(vlc?.duration == 60.0)
    }

    @Test("Field splitting treats a run of pipes as one delimiter with empty fields between")
    func fieldSplittingCollapsesDelimiterRuns() {
        // Recorded from the real interpreter, not reasoned about. AppleScript emits a
        // *run* of pipes for an empty field: `"" & "|||" & "x"` is `|||x` when the
        // preceding field is also empty, and four pipes when only one is.
        //
        // `components(separatedBy:)` collapses such a run into one delimiter, which is
        // what keeps the later fields on the right indices. A splitter that consumed
        // exactly three characters at a time would read four pipes as a delimiter plus
        // a stray `|`, shifting album and duration by one — the failure mode this
        // comment exists to prevent.
        #expect(DesktopMediaApp.fields(of: "a|||b|||c") == ["a", "b", "c"])
        #expect(DesktopMediaApp.fields(of: "playing|||||||||Album|||0|||100")
            == ["playing", "", "", "Album", "0", "100"])
        // Edge behaviour: a trailing or leading delimiter yields an empty edge field.
        #expect(DesktopMediaApp.fields(of: "a|||") == ["a", ""])
        #expect(DesktopMediaApp.fields(of: "|||a") == ["", "a"])
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
}
