# AGENTS.md — Contributor & AI Agent Guide

General rules for changing this codebase. No feature specifics live here — those are
in [`docs/`](docs/), indexed in [`docs/README.md`](docs/README.md).

If a rule here seems obvious, it is because it was learned the hard way. Keep the
*why* when you extend this file — a bare rule gets reverted by whoever didn't know it
was deliberate.

---

## 1. 🚨 Behaviours Must Be Code-Enforced

> **"Prefer code that guarantees behaviour, not docs or comments."**

A constraint the app must respect has to be executable code that fails loudly when
violated. Prose is invisible at the edit site, doesn't survive refactors, and never
reaches someone who didn't read it — a constraint in prose is a wish.

**1.1 Use the strongest level available:**

| Level | Mechanism | Buys you |
| :--- | :--- | :--- |
| 1 | Type-level — make it unrepresentable | The compiler rejects it forever, including in code not yet written |
| 2 | Required conformance — omission won't compile | A new implementer can't skip the contract by not knowing it exists |
| 3 | Single choke point — all paths validate | Later call sites are covered automatically |
| 4 | Automated guard — fails the build | Regressions caught without anyone remembering the rule |
| 5 | `#if DEBUG` diagnostic | Evidence only, never the guarantee |
| ❌ | Comment / doc / checklist | Never sufficient alone |

**A guard is done when** the illegal case is impossible (1) or won't compile (2),
there is one entry point, it covers every call site, the invariant is unit-testable as
a pure function, and any override is one centralised flag. Reach for a type before
reaching for a validator.

---

## 2. 🧩 Design Principles

Commitments that are expensive to reverse.

**2.1 Global state is load-bearing, not legacy.** State lives in process-wide
singletons, deliberately — the project's concurrency language mode is coupled to it.
Undoing it is its own project with its own plan, not a drive-by.

**2.2 Adapt content to a fixed surface, never the surface to the content.** When a
surface's geometry is owned by something you don't control — a hardware cutout, a
bezel — treat its size as a constant and let content scale, truncate, or swap to a
glyph. A surface that resizes to fit content reads as a glitch.

**2.3 Encode a surface's constraints in its type, not in a render branch.** A
character budget or a rule against text belongs in the type that feeds the surface;
filtering at the render site is bypassed by the next branch you add. A closed enum is
both the enforcement mechanism and the test surface.

**2.4 Separate structure from content.** Presentation layers own structure —
framing, navigation, transitions — and content is shared. Needing different content
means a new content type, not a new variant.

**2.5 A discrete action needs a discrete recognizer.** A continuous gesture reports
nothing on a still input, so never derive select / submit / confirm from its end
callback. Transient interaction state must also be recoverable: a gesture whose
release can be lost must be detected and dropped, never left pinned — pinned state
silently disables every other target.

**2.6 System signals are lossy; corroborate before acting.** OS-reported state is
often ambiguous, stale, or self-contradictory. No single signal is authoritative, and
noisy ones need debouncing. Degrade to an honest empty state rather than a confident
wrong one.

**2.7 Never fabricate system state.** No demo mocks, simulated activity, or
stand-ins for a capability the app does not have.

---

## 3. 🧪 Testability Is a Design Constraint

**The test target accepts pure logic only** — headless, no window server, no app
launch, no ambient global state.

That is a design signal, not an inconvenience: code that resists headless testing
usually reaches for a global instead of accepting its inputs. So make a guarded rule a
**pure function of its parameters** — the guard and the test surface become the same
code. Adding a test to code that reaches for a global means a refactor first.

→ What may live there, and the specific traps: [`docs/TESTING.md`](docs/TESTING.md).

---

## 4. 🔨 Build Invariants

- **The two toolchains stay separate.** One script builds the app; the package manager
  runs tests only. Don't unify them.
- **Set `DEVELOPER_DIR` on every toolchain invocation** or the compiler can block on
  an interactive license prompt. Scripts must not depend on the caller's shell.
- **`build_app.sh` is the only way to produce the bundle,** and it installs to
  `~/Applications` — run and test from there, never from `build/` (§6.2).
- **Zero third-party dependencies.** Adding one would have to reach both build paths to
  mean anything.
- **Adding or removing a framework?** Update the build script and the framework
  inventory together, or the two will disagree.
- **`main` is the branch of record and it is public,** with no CI and no review gate.
  Never force-push it (§6.3).

---

## 5. 📝 How To Write Documentation

Docs are split by audience; wrong content in the wrong file is the failure to
prevent.

| File | Contains | Must **not** contain |
| :--- | :--- | :--- |
| **`README.md`** | Summary, features, deps, build, tests, shortcuts, layout | Architecture, API reference, feature specs |
| **`AGENTS.md`** | General principles, non-obvious constraints, build invariants | How any feature works, walkthroughs, constants, file inventories |
| **`docs/*.md`** | Feature specs, subsystem architecture, gotchas, tutorials | Anything belonging to the two above |

**Placement test:** still true after the implementation is deleted and rewritten? →
`AGENTS.md`. Describes what the code currently *is*? → `docs/`. Answers "can I run
this?" → `README.md`.

1. **One home per fact.** Where another file needs it, link to the owner —
   restatement is how two copies diverge.
2. **No feature specifics here.** A named subsystem, constant, or widget belongs in
   `docs/`.
3. **Keep this file short.** Past roughly 300 lines it has become a manual.
4. **Name `docs/` files for the area,** not a release or a date, and index each new
   one in [`docs/README.md`](docs/README.md).
5. **State the *why* beside each constraint** — a reason survives the next refactor.
6. **Verify every claim against the code** before writing it; if you can't check it,
   say so rather than shipping a confident wrong fact.
7. **Update docs in the same change as the code.** A doc describing old behaviour is
   a bug in the doc.

---

## 6. 🔁 Change Discipline

**6.1 A major feature is followed by its own refactor commit.** Refactor only the
modules the feature actually left worse, as a **separate commit**. A feature commit
gets written while the shape is still being discovered, so folding the cleanup in
hides how much was retrofitted — and the provisional structure survives because nobody
ever priced it. Widening the blast radius past the modules the feature worsened turns a
passing suite into an unmeasured one.

**6.2 A change is not done until it has been built, installed, and seen running.**

```bash
./scripts/build_app.sh && pkill -f DynamicIsland; sleep 0.4; open ~/Applications/DynamicIsland.app
```

Pure-logic tests cannot cover geometry, hit-testing, animation, the notch seal, or
media *integration* — a green suite says nothing about whether the island drew. A
*stale* process is worse than no observation: it reports the previous build and reads
as a failed change. So relaunch before judging (a second instance will not take over
from the first), launch the installed path (a binary run from `build/` skips
`Info.plist`, losing `LSUIElement`), and keep one copy on disk — two bundles sharing
one id make Launch Services' choice ambiguous, which the build script warns about.
Then show what you saw, and say plainly what can't be checked headlessly.

**6.3 Confirmed-working changes get committed and pushed.** Implement → build and
show (§6.2) → *the user confirms* → commit and push.

```bash
git add -A && git commit -m "…" && git push origin main
```

The confirmation is the gate: tests prove the policy functions, only the user can
confirm the feature does what they meant. Silence isn't approval, and a confirmation
already given isn't to be asked for twice. Read what `git add -A` staged before
committing — a *tracked* file is never ignored, so a stray artifact reaches a public
repo. Never force-push `main`; fetch and rebase instead. Report the range you pushed,
and say so if it includes commits from before the confirmed feature.

Pushing does not create or update a GitHub release — `v0.1.0` is cut deliberately and
separately, for the same reason refactors get their own commit.
