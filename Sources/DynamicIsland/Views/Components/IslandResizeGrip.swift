import SwiftUI
import AppKit

/// The island's resize affordance: a diagonal-resize cursor on the island's
/// bottom-right corner, in place of a button.
///
/// Shown only when `AppState.isResizable` — that is, when an integrated-app plugin
/// owns the active tab. Tool tabs keep their fixed geometry (docs/DESIGN.md §1).
///
/// # Why there is no visible affordance
///
/// Earlier versions drew a glowing rim here, on the theory that a discoverable
/// affordance is worth the visual cost. It was not. The island's bottom-right corner
/// is already a distinctive, unbroken piece of glass, and a brightening edge there
/// read as an active or selected state rather than as a handle — so it drew the eye
/// to a part of the island that does nothing until it is dragged.
///
/// The cursor carries the affordance instead, which is how AppKit itself signals a
/// resizable window: there is no persistent handle, and the cursor changes as the
/// pointer approaches. Nothing is drawn, so there is also nothing to misread, nothing
/// to cover the island's edge, and no second element to keep aligned with it.
///
/// The drag target therefore has to be larger than anything visible, which is what
/// `IslandGripRegion` is for — with no rim to look at, the region *is* the affordance,
/// and a too-small one would be undiscoverable in both directions.
///
/// # Why the drag writes through `AppState`
///
/// The island is drawn inside a borderless, transparent panel, so macOS supplies no
/// resize cursor and no resize corner: an `NSPanel` with no title bar gets neither.
/// The panel is a click-through canvas deliberately larger than the island, and the
/// island is top-anchored, so resizing the panel itself would move the island's top
/// edge off the screen.
struct IslandResizeGrip: View {
    /// Which bottom corner this grip occupies.
    ///
    /// The island grows symmetrically about centre during a drag, so the two
    /// corners are interchangeable for the user's purpose. The corner is still
    /// named explicitly here rather than left implicit because the gesture must
    /// pick the right sign to feed `resizeActiveTab`: pulling the leading corner
    /// outward is the same direction in screen space as pulling the trailing corner
    /// inward, and the function takes the corner, not a hand-signed translation,
    /// so there is no way to invert the direction by accident.
    let corner: IslandGripCorner

    @ObservedObject var appState = AppState.shared

    /// The size the drag started from, captured on the first frame.
    @State private var dragStartSize: IslandSize?

    /// The cursor shown while the pointer is over the corner.
    ///
    /// Built once and cached: `NSCursor` is a process-wide resource, and
    /// `NSCursor.set()` on every hover would churn it.
    @State private var cursor: NSCursor = IslandResizeGrip.makeDiagonalCursor(.bottomTrailing)

    /// Whether the pointer is inside the corner's region.
    @State private var isHovering = false

    var body: some View {
        GeometryReader { geo in
            hitTarget(in: geo.size)
        }
        .onAppear {
            // The cursor is a process-wide singleton, so it is built once per corner
            // rather than per view; `corner` is fixed for this view's lifetime, so
            // this is the only place the glyph's direction is chosen.
            cursor = IslandResizeGrip.makeDiagonalCursor(corner)
        }
    }

    /// The only part of this view that accepts input: a rounded square on the named
    /// bottom corner, kept clear of the header so it can never shadow the pin button.
    ///
    /// The rect is computed by `IslandGripRegion` rather than written out here. When
    /// this was a hand-written `CGRect(x: width - side, y: 0, …)` it looked correct
    /// and was catastrophically wrong: SwiftUI's `y` grows downward, so `y: 0` is the
    /// island's *top* edge. The invisible region sat over the header, on the unpin
    /// button, and both unpin and the drag failed while the glow rendered perfectly —
    /// an affordance with no visible pixels is exactly the kind that is never checked
    /// by looking at it.
    private func hitTarget(in size: CGSize) -> some View {
        let region = IslandGripRegion(corner: corner, in: size)
        return Color.clear
            .contentShape(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .path(in: region.rect)
            )
            .frame(width: size.width, height: size.height)
            .onHover { inside in
                isHovering = inside
                if inside { cursor.set() }
            }
            .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        // `global` so the translation is measured in screen space, which is what
        // the user is actually dragging. A local-space translation would be skewed
        // by the island's own frame morphing underneath the pointer mid-drag.
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                // The first frame establishes the origin; later frames reuse it, so
                // the size is re-derived from a fixed start every time rather than
                // accumulated frame by frame.
                let origin = dragStartSize ?? appState.resolvedSizeForActiveTab()
                if dragStartSize == nil { dragStartSize = origin }
                // The corner is passed rather than a pre-signed translation: the sign
                // is derived from which edge is being dragged, inside `AppState`, so
                // there is no way to hand this function an inverted delta by accident.
                appState.resizeActiveTab(by: value.translation, from: origin, at: corner)
            }
            .onEnded { _ in
                dragStartSize = nil
                // Also clears `activeResizeCorner`, which is what zeroes the island's
                // tracking shift and lets it spring back to centre.
                appState.endResize()
            }
    }

    /// A diagonal double-arrow cursor, which AppKit does not ship.
    ///
    /// This is now the entire affordance, so it has to be legible on the island's
    /// glass at every point along the region — not just where a visible rim used to
    /// guide the eye.
    ///
    /// `NSCursor.resizeLeftRight` and `resizeUpDown` are public, but there is no
    /// public diagonal — verified on this machine rather than assumed — and the
    /// private `_windowResize` class is not something to depend on. So the glyph is
    /// drawn: two strokes in a template image, which means it follows the light and
    /// dark appearance automatically.
    ///
    /// Drawn in code rather than shipped as a 16×16 asset because a two-line
    /// template PNG in the bundle is a binary nobody can review, and this is three
    /// lines of path.
    ///
    /// The hot spot sits on the corner the drag *starts from*, not always the trailing
    /// one. On the bottom-left the pointer's own point is the island's left edge, so a
    /// trailing-corner hot spot would put the cursor's tip ~14pt away from the edge being
    /// dragged, and the island would appear to start moving only once the pointer had
    /// already crossed inside it.
    private static func makeDiagonalCursor(_ corner: IslandGripCorner) -> NSCursor {
        let side: CGFloat = 16.0
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let inset = rect.insetBy(dx: 1.5, dy: 1.5)
            let path = NSBezierPath()
            path.lineWidth = 1.2
            path.lineCapStyle = .round

            // The two diagonals of the square, leaving the outer corner clear for
            // the arrowheads.
            path.move(to: NSPoint(x: inset.minX, y: inset.minY))
            path.line(to: NSPoint(x: inset.maxX, y: inset.maxY))
            path.move(to: NSPoint(x: inset.maxX, y: inset.minY))
            path.line(to: NSPoint(x: inset.minX, y: inset.maxY))
            path.stroke()

            return true
        }
        image.isTemplate = true
        // Hot spot on the corner the drag starts from, so the cursor's point sits
        // where the island's edge actually is.
        let hotSpot = corner == .bottomLeading
            ? NSPoint(x: 1.5, y: 1.5)
            : NSPoint(x: side - 1.5, y: 1.5)
        return NSCursor(image: image, hotSpot: hotSpot)
    }
}
