# AGENTS.md — Contributor & AI Agent Guide

General rules for changing this codebase.
Feature specifics live in [`docs/`](docs/), indexed in [`docs/README.md`](docs/README.md).

A rule earns its place here by being **learned the hard way**.
The *why* is what stops it being reverted as redundant; if a rule is obvious from the code, it does not belong in this file.

---

## 1. 🚨 Behaviours Must Be Code-Enforced

A constraint the app must respect has to be executable code that fails loudly when violated — prose is invisible at the edit site and doesn't survive refactors.

**1.1** Use the strongest level: **1** type-level (make it unrepresentable) · **2** required conformance (won't compile) · **3** single choke point · **4** build-failing guard · **5** `#if DEBUG` (evidence only, never the guarantee).
Comments and docs never count.
Reach for a type before a validator.

---

## 2. 🧩 Design Principles

Commitments that are expensive to reverse.

**2.1 Global state is load-bearing, not legacy.** Singletons are deliberate and the concurrency language mode is coupled to them; modernising is its own project, not a drive-by.

**2.2 A surface's size is a constant.** When geometry is owned by something you don't control — a cutout, a bezel — let content adapt instead: scale, truncate, or swap to a glyph.
Resizing the surface reads as a glitch.

**2.3 Encode a surface's limits in its type,** not in a render branch, which the next branch you add bypasses silently.
A closed enum is both the enforcement mechanism and the test surface.

**2.4 Separate structure from content.** Presentation owns framing, navigation, and transitions; needing different content means a new content type, not a new variant.

**2.5 A discrete action needs a discrete recognizer.** A continuous gesture reports nothing on a still input, so never derive select/submit/confirm from its end callback; and transient state whose release can be lost must be dropped, never left pinned.

**2.6 System signals are lossy.** Corroborate before acting, debounce noisy ones, and degrade to an honest empty state rather than a confident wrong one.

**2.7 Never fabricate system state.** No demo mocks, simulated activity, or stand-ins for a capability the app does not have.

---

## 3. 🧪 Testability Is a Design Constraint

**The test target accepts pure logic only** — headless, no window server, no app launch, no ambient globals.
That is a design signal, not an inconvenience: code that resists headless testing is usually reaching for a global instead of accepting its inputs, so make any rule worth guarding a **pure function of its parameters** — the guard and the test surface become the same code.

→ What may live there, and the traps: [`docs/TESTING.md`](docs/TESTING.md).

---

## 4. 🔨 Build Invariants

- **`scripts/build_app.sh` is the only way to produce the bundle,** and it installs to `~/Applications` and nowhere else.
  Never run from `build/` — that skips `Info.plist`, and `LSUIElement` lives there.
- **Set `DEVELOPER_DIR` on every toolchain invocation** or the compiler can block on an interactive license prompt.
  Scripts must not depend on the caller's shell.
- **The two toolchains stay separate:** the script builds, the package manager only tests.
  Don't unify them.
- **Zero third-party dependencies.** One would have to reach both build paths to mean anything.
- **Adding or removing a framework?** Update the build script and the framework inventory together, or the two will disagree.

---

## 5. 📝 How To Write Documentation

Docs are split by audience, and wrong content in the wrong file is the failure to prevent.
`README.md` answers "can I run this?"; `docs/` describes what the code currently *is*; this file holds only what stays true after the implementation is deleted and rewritten.
One fact, one home — link to the owner rather than restating, because two copies always diverge.
Name new docs for the area and index them in [`docs/README.md`](docs/README.md).

Verify every claim against the code before writing it, and update docs in the same change as the code: a doc describing old behaviour is a bug in the doc.
**Never break a line mid-sentence — keep one sentence per line,** so a reader never has to rejoin fragments to find where a thought ended.

---

## 6. 🔁 Change Discipline

**6.1 A major feature is followed by its own refactor commit,** touching only the modules the feature actually left worse.
A feature commit gets written while the shape is still emerging, so folding the cleanup in hides how much was retrofitted.

**6.2 A change is not done until it has been built, installed, and seen running.** Pure-logic tests can't tell you whether the island drew, and a stale process is worse than no observation — it reports the previous build and reads as a failed change.
Relaunch rather than just build (a second instance will not take over from the first), and show what you saw, saying plainly what can't be checked headlessly:

```bash
./scripts/build_app.sh && pkill -f DynamicIsland; sleep 0.4; open ~/Applications/DynamicIsland.app
```

**6.3 Commit and push only once the user has confirmed the feature works.** Tests prove the policy functions; only they can confirm it does what they meant, and silence is not approval.
`main` is public with no CI and no review, so never force-push it, and a *tracked* file is never ignored — read what you staged.
Pushing does not cut a release; `v0.1.0` was tagged separately, for the same reason refactors get their own commit.
