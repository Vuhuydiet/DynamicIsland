# AGENTS.md — Contributor & AI Agent Guide

General rules for changing this codebase. **No feature-specific facts live here** —
no file inventories, no constants, no subsystem walkthroughs, no per-feature gotchas.
Those are in [`docs/`](docs/), indexed in [`docs/README.md`](docs/README.md).

If a rule below seems obvious, it is here because it was learned the hard way. The
*why* is the valuable part; keep it when you extend the file.

---

## 1. 🚨 Behaviours Must Be Code-Enforced

> **"Prefer code that guarantees behaviour, not docs or comments."**

Any constraint the app must respect — what to do, or what never to do — must live in
**executable code that fails loudly when violated**. Prose fails three ways: it is
invisible at the edit site, it does not survive refactors, and it cannot reach a
contributor or agent who never read it. A behaviour described only in prose is a wish.

### 1.1 Use the strongest level available

Work **down** this list:

| Level | Mechanism | What it buys you |
| :--- | :--- | :--- |
| 1 | **Type-level** — make it unrepresentable | The compiler rejects it forever, including in code you haven't written yet |
| 2 | **Required conformance** — omission won't compile | A new implementer cannot skip the contract by not knowing about it |
| 3 | **Single choke point** — all paths validate | Later call sites are covered *automatically*, because they cannot bypass it |
| 4 | **Automated guard** — fails the build | Regressions are caught without anyone remembering the rule |
| 5 | **`#if DEBUG` diagnostic** | Evidence only — never the primary guarantee |
| ❌ | Comment / doc / checklist | **Never sufficient alone** |

**A guard is finished when** the illegal case is *impossible* (1) or *won't compile*
(2); there is exactly one entry point; it covers every call site; the invariant is
unit-testable as a pure function; and any override is one centralised flag rather than
scattered per-call-site conditionals.

Levels 1 and 2 are strictly better than 3, and 3 strictly better than 4. Reach for a
type before reaching for a validator.

---

## 2. 🧩 Design Principles

Commitments that are expensive to reverse.

**2.1 Global state is load-bearing, not legacy.** State lives in process-wide
singletons. This is a deliberate choice for a single-window app, and the project's
concurrency language mode is coupled to it. Do not "modernise" it into dependency
injection as a drive-by; that is its own project with its own plan.

**2.2 Adapt content to a fixed surface, never the surface to the content.** When a
surface has geometry owned by something outside your control — a hardware cutout, a
reserved region, a bezel — its size is a constant. Let content adapt (scale,
truncate, swap to a glyph) rather than resizing the surface. A surface that changes
size in response to content reads as a glitch, not as responsiveness.

**2.3 Encode a surface's constraints in its type, not in a render branch.** If a
surface has an inherent limit — a character budget, a rule against text, a required
affordance — make the type that feeds it incapable of violating that limit. Filtering
at the render site is not enforcement: the next branch you add bypasses it silently.
A closed enum is both the enforcement mechanism and the test surface.

**2.4 Separate structure from content.** When a feature has multiple presentations
(layout variants, themes, shells), the presentation layer owns *structure* — framing,
navigation, transitions — and the content layer is shared and universal. A new
presentation must never fork or special-case content; needing different content means
adding a new content type, not a new variant of the old one.

**2.5 A discrete action needs a discrete recognizer.** Continuous gestures
(drag, long-press) with a movement threshold report *nothing* on a still input, so
never derive a discrete action (select, submit, confirm) from their end callback — it
does nothing, intermittently. Also: transient interaction state must always be
recoverable. If a gesture's release can be lost, it must be *detected and dropped*,
never left pinned — pinned state silently disables every other target.

**2.6 System signals are lossy; corroborate before acting.** OS-reported state is
frequently ambiguous, stale, or self-contradictory. Treat no single signal as
authoritative, and debounce noisy ones so transient misses do not flicker the UI.
Failing that, degrade to an honest empty state rather than a confident wrong one.

**2.7 Never fabricate system state.** Production code reflects reality. No demo
mocks, simulated activity, or stand-ins for a capability the app does not have.

---

## 3. 🧪 Testability Is a Design Constraint

**The test target accepts pure logic only** — it runs headless, with no window
server, no app launch, and no ambient global state.

This is a design signal, not a testing inconvenience: code that cannot be tested
headlessly usually reaches for a global internally instead of accepting its inputs.
So when a rule is worth guarding, make it a **pure function that takes its inputs as
parameters** — then the guard and the test surface are the same code, and designing
one designs the other. Keep policy types `Equatable`/`Codable` so assertions stay
trivial.

Reach for this *while* writing the guard, not after. Adding a test to code that
reaches for a global means a refactor, not a test.

→ What may live in the test target, and the specific traps, are in
[`docs/TESTING.md`](docs/TESTING.md).

---

## 4. 🔨 Build Invariants

- **The two toolchains are deliberate and must stay separate.** One script produces
  the shipping app; the package manager runs tests only. Do not unify them.
- **Set `DEVELOPER_DIR` on every toolchain invocation**, or the compiler can block on
  an interactive license prompt. Automated scripts must not depend on the caller's
  shell.
- **The build script is the only way to produce the app bundle**, and it installs
  there. Run and test the app from that installed path, not from a build directory.
- **The project has zero third-party dependencies.** Keep it that way; adding one
  would need to reach both build paths to mean anything.
- **Adding or removing a framework?** Update the build script and the framework
  inventory together, or the two will disagree.

---

## 5. 📝 How To Write Documentation

> **This section is the rule the rest of the repo's docs must satisfy.**

Docs are split by **audience and intent**. Wrong content in the wrong file is the
failure this prevents: a principles file full of feature archaeology is unreadable, and
a README explaining subsystem internals is a manual nobody asked for.

| File | Audience | Contains | Must **not** contain |
| :--- | :--- | :--- | :--- |
| **`README.md`** | Deciding whether to use/build this | Summary, features, dependencies, build, tests, shortcuts, layout | Architecture, implementation detail, API reference, feature specs |
| **`AGENTS.md`** | About to change code | **General principles**, non-obvious constraints, build invariants, this rule | How any feature works, walkthroughs, constants, file inventories |
| **`docs/*.md`** | Working on one area | Feature specs, subsystem architecture, gotchas, API usage, tutorials | Anything belonging to the two files above |

**Placement test:** would this still be true and useful after the implementation is
deleted and rewritten? → principle, `AGENTS.md`. Does it describe what the code
currently *is*? → `docs/`. Does it answer "can I run this?" → `README.md`.

1. **Never duplicate a fact across files.** Each fact has exactly one home. Where
   another file needs it, link to the owner — restatement is how docs rot, and two
   copies always diverge. This applies to tables, constants, and command lines too.
2. **No feature specifics in `AGENTS.md`.** If it names a subsystem, a constant, or a
   widget, it belongs in `docs/`.
3. **Keep this file short.** Past roughly 300 lines it has become a manual.
4. **Name `docs/` files for the area**, not a release or a date. Index every new doc
   in [`docs/README.md`](docs/README.md), and link it from here only if it is relevant
   to *changing* code rather than *using* the app.
5. **State the *why* beside each constraint.** A reason survives the next refactor; a
   bare rule gets reverted by whoever didn't know it was deliberate.
6. **Verify every claim against the code before writing it.** Do not carry a number
   or a behaviour forward from memory or from an older doc — check it, and if you
   cannot, say so rather than shipping a confident wrong fact.
7. **Update docs in the same change as the code.** A doc describing the old behaviour
   is a bug in the doc.
