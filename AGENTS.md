# AGENTS.md — Contributor & AI Agent Guide

General rules for changing this codebase — how to enforce a behaviour, how to make a call, how to build, and how to document.
These apply everywhere; anything specific to one design does not belong here.

The commitments this app is built on live in [`docs/DESIGN.md`](docs/DESIGN.md), and feature specifics in [`docs/`](docs/), indexed in [`docs/README.md`](docs/README.md).

A rule earns its place here by being **learned the hard way**.
The *why* is what stops it being reverted as redundant; if a rule is obvious from the code, it does not belong in this file.

---

## 1. 🚨 Behaviours Must Be Code-Enforced

A constraint the app must respect has to be executable code that fails loudly when violated — prose is invisible at the edit site and doesn't survive refactors.

**1.1** Use the strongest level: **1** type-level (make it unrepresentable) · **2** required conformance (won't compile) · **3** single choke point · **4** build-failing guard · **5** `#if DEBUG` (evidence only, never the guarantee).
Comments and docs never count.
Reach for a type before a validator.

---

## 2. 🧭 Working Principles

Rules for making the call, not instructions about this app's design.
The commitments this app is built on live in [`docs/DESIGN.md`](docs/DESIGN.md) — this file is only what applies everywhere.

**2.1 Decide for the long term, and decide it yourself.** When two designs are defensible, pick the one that is still right after the next few rewrites — not the cheaper one today, and not the one that defers the choice.
Deferring is a decision, and it is the expensive kind: it leaves an unmade decision inside code that now depends on it.
So make the call, state the choice and its reasoning briefly, and let the user redirect — handing back a menu of options for a call that is yours to make is a tax, not caution.
Ask only when it is genuinely theirs: their product, their machine, their risk, their money.

**2.2 Fix the mechanism, not the symptom.** When a behaviour is wrong, the defect is a *cause*; the visible annoyance is only where that cause happens to surface.
So find the thing that makes the symptom unavoidable, and change that — a fix that leaves the cause in place is a workaround, and it will read as a workaround to the next person, who will then either re-patch it or build on it.
A symptom fix is recognisable in hindsight: it adds a threshold, a tolerance, a delay, a retry, a special case, or a "just while this is happening" guard.
Those are the signatures of treating the observation instead of the mechanism, because each one buys correctness by *disagreeing less often* rather than by being right.
The cause is usually structural — an ownership mistake, a duplicated source of truth, work on the wrong layer — and those are worth the larger change, because a structural cause is the only kind that stops coming back.
Corollary: **never trade a mechanism for a magic number.** If a fix needs a constant tuned to hide a race, the race is still there.

---

## 3. 🧪 Testability Is a Design Constraint

**The test target accepts pure logic only** — headless, no window server, no app launch, no ambient globals.
That is a design signal, not an inconvenience: code that resists headless testing is usually reaching for a global instead of accepting its inputs, so make any rule worth guarding a **pure function of its parameters** — the guard and the test surface become the same code.

→ What may live there, and the traps: [`docs/TESTING.md`](docs/TESTING.md).

---

## 4. 🔨 Build Invariants

- **`scripts/build_app.sh` is the only way to produce the bundle,** and it installs to `/Applications` and nowhere else.
  Never run from `build/` — that skips `Info.plist`, and `LSUIElement` lives there.
  It refuses to fall back to another directory when `/Applications` is unwritable, because a silent second copy
  makes "did my change take effect?" unanswerable; it fails and asks for `sudo` instead.
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
./scripts/build_app.sh && pkill -f DynamicIsland; sleep 0.4; open /Applications/DynamicIsland.app
```

**6.3 Commit and push only once the user has confirmed the feature works.** Tests prove the policy functions; only they can confirm it does what they meant, and silence is not approval.
`main` is public with no CI and no review, so never force-push it, and a *tracked* file is never ignored — read what you staged.
Pushing does not cut a release; `v0.1.0` was tagged separately, for the same reason refactors get their own commit.

**6.4 The running app is the review — never gate work on a document sign-off.**
The user verifies changes by using the app, not by reading prose; design docs, specs, and plans are not a gate they will pass through, and asking them to review one is a wasted round trip.
So decide the design yourself (§2.1), implement, and go straight to §6.2 — build, install, relaunch, and report what you actually observed.
This makes §6.2 *the* review step rather than a final flourish: if the launch was skipped, there is nothing to review and the change is not finished.
`AGENTS.md` is the deliberate exception — it *is* read — so treat an edit to it as a real change to be confirmed, and keep it free of anything that only matters to one feature.
