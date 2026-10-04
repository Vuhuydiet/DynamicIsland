import Testing
import Foundation
@testable import DynamicIsland

// MARK: - Docking mode policy
//
// The island presents either as a notch-attached island or as a floating pill, and
// that one boolean decides island geometry, the drawn silhouette, and the clickable
// hit region. The hit region is hand-written open-top arithmetic that this project
// learned the hard way (see `docs/ARCHITECTURE.md` §2), and it is the reason the
// decision was previously duplicated at seven call sites: a copy that drifted would
// make the island *look* clickable in one place and behave dead in another, with no
// build error to catch it.
//
// `DockingMode.isNotchMode` is now the single definition, and this pins the policy:
// the user's explicit preference must always win, `.auto` must follow the hardware,
// and there must be no combination of the two that yields an undefined answer.

@Suite("Docking mode policy")
struct DockingModeTests {

    @Test("An explicit preference always wins over the detected hardware")
    func explicitPreferenceOverridesHardware() {
        // `.notch` attaches even to a screen with no notch, and `.floating` floats
        // even on a notched one. That is the whole point of overriding `.auto` —
        // for an external display, or to demo the floating look on a notched laptop.
        #expect(DockingMode.isNotchMode(style: .notch, hasPhysicalNotch: false) == true)
        #expect(DockingMode.isNotchMode(style: .notch, hasPhysicalNotch: true) == true)
        #expect(DockingMode.isNotchMode(style: .floating, hasPhysicalNotch: true) == false)
        #expect(DockingMode.isNotchMode(style: .floating, hasPhysicalNotch: false) == false)
    }

    @Test("Auto follows the hardware in both directions")
    func autoFollowsHardware() {
        #expect(DockingMode.isNotchMode(style: .auto, hasPhysicalNotch: true) == true)
        #expect(DockingMode.isNotchMode(style: .auto, hasPhysicalNotch: false) == false)
    }

    @Test("Every style resolves, for both hardware states, with no undefined answer")
    func policyIsTotal() {
        // Exhaustive over `NotchStyle.allCases`. A new docking style that the policy
        // forgets will not compile without a new `case` here, which is the point of
        // routing every call site through this one function.
        for style in NotchStyle.allCases {
            for hasNotch in [true, false] {
                #expect(
                    DockingMode.isNotchMode(style: style, hasPhysicalNotch: hasNotch) == (style == .notch || (style == .auto && hasNotch)),
                    "\(style.rawValue) / hasNotch=\(hasNotch)"
                )
            }
        }
    }
}
