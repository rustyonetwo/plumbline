# AGENTS.md

Instructions for coding agents working in this repository.

This project exists to demonstrate a specific practice, so *how* you
work here is part of the point. Read this file before changing
anything.

## What this repository is

A minimal, complete example of **proof-driven development**: the
mathematical invariants of a system are written first, as an executable
Livebook, and the implementation is built to satisfy them.

`livebooks/hcw_orbital_mechanics.livemd` is the **specification**. It
is not a test file and it is not documentation *about* the code — it is
the ground truth the code must satisfy. It states the physics in
narrative, derives three invariants in full, and asserts them
executably.

Read it before you write a line of Elixir. It will teach you the domain
if you don't know it.

Proof-driven development is the rigorous end of a broader practice —
invariant-driven development — where an executable notebook checks a
property that holds generally (true for every valid input, not a fixed
case) and can be derived or independently measured without sharing code
with the implementation. Not every domain has a closed-form oracle the
way orbital mechanics does.

`hcw_orbital_mechanics.livemd` is the proof-tier notebook and the
repository's primary artifact — it is what makes the "proof" in
proof-driven development an honest word.

Notebooks here are kept to one job each, and the rule is worth stating
plainly: **a notebook that governs invariants is not also a
deliverable.** The specification changes rarely, is reviewed as
mathematics, and is what CI gates on; anything that exists to be looked
at churns on a different clock, and coupling the two means every
presentational edit lands in the file that defines correctness. So:

| Notebook | Job |
|---|---|
| `hcw_orbital_mechanics.livemd` | States the physics, derives the invariants, asserts them. No plotting, and no dependencies beyond this project. |
| `hcw_visualisation.livemd` | Draws relative orbits. Judges nothing, gates nothing. |

A further notebook asserting some additional invariant belongs
alongside these rather than folded into either, and is gated the same
way — see "Verifying your work".

## The cardinal rule

**Never edit the notebook to make an assertion pass.**

The notebook is a wall. The implementation bounces off it. If an
assertion fails, the implementation is wrong — that is what the
assertion is for.

If you become convinced an assertion itself is incorrect, **stop and
say so.** Explain which claim you believe is wrong and why, and let a
human decide. Do not quietly loosen a tolerance, delete a check, or
adjust an initial condition to get a green run. An invariant that
yields under pressure guards nothing.

This applies to tolerances especially. They were chosen to catch
*physics* errors, not to accommodate an implementation that doesn't
quite work.

## Direction of dependency

```
notebook  ──specifies──▶  lib/
```

One way only. `lib/` must never reference, import, or read the
notebook. The notebook may reference `lib/`.

Related: `Plumbline.Dynamics.HCW.analytic/3` is an **independent
oracle**. It implements the closed-form solution and the notebook
cross-checks the numerical trajectory against it at every sample. That
check is worthless if the two share code, so `analytic/3` must not call
`derivative/2`, `step/3`, or `propagate/4`, and must be derived from the
analytic solution in the notebook rather than from them.

## Order of work

1. **Invariants first**, in the notebook, written by a human.
2. **Implementation**, satisfying them.
3. **Unit tests**, descending from the invariants — edge cases, error
   paths, boundary values the property assertions don't naturally
   exercise.

Unit tests never precede the invariants they descend from. When the
notebook gains a new rule, tests follow it; not the reverse.

The two layers guard different things. The notebook guards that
*invariants hold*. Tests guard that *specific cases are correct*. An
implementation can satisfy every unit test while breaking physics, or
break every unit test while preserving it. Both layers must be green.

## Domain traps

These are real errors that produce plausible-looking output. The
notebook derives all of them; this is the short version.

- **The drift-free condition is on the along-track velocity**, not the
  radial one: `vy₀ = -2·n·x₀`, with `vx₀` free. Applying it to `vx`
  instead is a one-character transposition that produces `12π·x₀` of
  along-track drift per orbit — **37.7 km for a 1 km offset, at any
  altitude**. The first few minutes of that trajectory look correct.

- **Use RK4, not the closed-form state transition matrix**, for
  `step/3` and `propagate/4`. With the exact solution, periodicity
  holds to machine epsilon by construction and the assertions stop
  meaning anything. The closed form belongs in `analytic/3` only.

- **RK4 is not symplectic.** It does not conserve the integral of
  motion exactly. Do not claim in code comments or documentation that
  it does.

- **The drift-free in-plane orbit is a 2:1 ellipse, not a circle.**
  `‖r‖` varies by a factor of two along it. A genuinely circular
  relative orbit requires cross-track motion (`z₀ = √3·x₀`).

- **Sign of the `x` term in the integral of motion is negative**
  (`-3/2·n²x²`), mirroring the destabilising `+3n²x` in the equations
  of motion. This is not orbital energy.

## Conventions

- Positions in **kilometres**, velocities in **km/s**, mean motion `n`
  in **rad/s**, time in **seconds**.
- LVLH frame: `x` radial (outward), `y` along-track, `z` cross-track.
- Floats throughout. No unit-carrying wrapper types — the notebook
  states units and the struct fields are documented.

## Constraints

- **No runtime dependencies.** The propagator is pure arithmetic and
  needs only `:math`. Visualisation dependencies (VegaLite, Kino) enter
  through the notebook's own `Mix.install`, never through `mix.exs`.
  Dev/test tooling must be `runtime: false`.
- **No suppressions to make tooling green.** Do not add
  `@dialyzer {:nowarn_function, ...}` or credo `# credo:disable-for-*`
  comments to hide a real finding. Fix the finding or explain why it
  should stand.
- Keep it small. One struct, one propagator, as few notebooks as the
  distinct concepts being demonstrated actually require. This is a
  demonstration, not a simulator — do not grow it into one.

## Verifying your work

```sh
mix compile           # must be warning-free
mix format --check-formatted
mix credo --strict    # must be clean
mix dialyzer          # must be clean
mix test
elixir verify_spec.exs  # independent check of the notebook's own claims
bin/run_checkpoint      # runs the specification notebook headlessly; exits 0 only if every invariant holds
elixir bin/checkpoint_history.exs   # every checkpoint run so far, as a trend
```

`bin/run_checkpoint` takes an optional notebook path (default: the
specification notebook) and deploys only that one. Any notebook that
loads `livebooks/checkpoint.exs`, declares its checks with
`Checkpoint.init/1`, records them with `Checkpoint.check/3` and ends
with `Checkpoint.complete/0` is gated the same way, and keeps its own
report history under `reports/<notebook name>/`. That is the seam for
adding an invariant later without touching the tooling.

`verify_spec.exs` is standalone — it needs no project and no
dependencies, and it validates the notebook's mathematical claims
against the closed-form solution. It does not test `lib/`.

**The notebook's assertions are the actual definition of done.**
`bin/run_checkpoint` deploys the notebook through Livebook's own
execution path and converts its checkpoint report into an exit code, so
this can be run unattended; opening the notebook in Livebook and
evaluating it by hand does the same thing with the plots rendered.
Requires Livebook on `PATH` (`mix escript.install hex livebook`).

The report distinguishes three outcomes: every check present and true
(exit 0); a check recorded `ok: false`, meaning the code ran but the
physics is wrong; and a missing completion sentinel, meaning evaluation
aborted on an uncaught exception rather than failing an assertion. A
failing check does not abort the run, so one pass reports on every
invariant rather than stopping at the first — and the final cell then
raises, so a failure is not something a reader can scroll past.

Runs accumulate in `reports/` (gitignored) rather than overwriting, and
`bin/checkpoint_history.exs` reads them as a trend. Consult it after
refactoring, not only after adding something: an invariant that was
passing and now fails is the exact regression this repository is built
to make visible, and it is far easier to see in a series than in a
single run.

Note that dialyzer will legitimately report `no_return` errors while
functions are stubs that raise. That is correct, not a bug to suppress
— it resolves when the functions are implemented.

## What this repository is not

- Not a general orbital mechanics library. HCW is a linearised model
  valid only for a circular chief orbit, small separations, and no
  perturbations. Do not add J2, drag, or eccentricity.
- Not a simulator, a mission planner, or a framework.
- Not a place for speculative abstraction. There is one implementation
  of one model; it does not need a behaviour, a protocol, or a plugin
  system.
- Not a place for absolute SLA thresholds — a fixed latency or memory
  number tied to one machine's hardware and load has no oracle to check
  it against, closed-form or otherwise, and is not an invariant. That
  material belongs in the talk, not an executable notebook here.
- A notebook demonstrating the *complexity* tier — e.g. confirming
  `propagate/4`'s growth is linear in step count by fitting a curve
  across increasing `N` — is in scope as a nice-to-have, separate from
  `hcw_orbital_mechanics.livemd`, and lower priority than it. It is a
  weaker, still-general claim (a growth shape true on any machine, not
  a proof), and belongs in its own notebook rather than folded into the
  physics one.
