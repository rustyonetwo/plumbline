# AGENTS.md

Bounds and working procedure for coding agents in this repository.

**This file contains nothing about how to implement anything.** The
specification is `livebooks/hcw_orbital_mechanics.livemd`. Read it
before writing a line of Elixir — it states the physics, derives the
invariants, defines the interface contract, and asserts all of it
executably. Where this file and the notebook appear to disagree about
the subject matter, the notebook is right and this file is out of date.

## The two notebooks are not the same kind of thing

| Notebook | Status |
|---|---|
| `hcw_orbital_mechanics.livemd` | **Authoritative.** The specification, and what CI gates on. |
| `hcw_visualisation.livemd` | Draws relative orbits. Judges nothing, gates nothing. |

## The cardinal rule

**Never edit a notebook to make an assertion pass.**

The notebook is a wall. The implementation bounces off it. If an
assertion fails, the implementation is wrong — that is what the
assertion is for. Do not loosen a tolerance, delete a check, or adjust
an initial condition to get a green run. An invariant that yields under
pressure guards nothing.

If you become convinced an assertion is itself incorrect, **stop and
say so.** Name the claim you believe is wrong and why, and let a human
decide.

## Bounds

- **Do not edit anything outside this repository.**
- **Do not run git commands** — no commits, branches, pushes, pulls,
  or checkouts. Stop and ask if something appears to require one.
- **Do not edit `hcw_orbital_mechanics.livemd`.** Not its assertions,
  not its prose. Some of its narrative goes stale as you work; say so
  in your summary rather than correcting it yourself. The same applies
  to `README.md`.
- **Invariants first, then implementation, then tests.** Unit tests
  never precede the invariants they descend from. Tests guard specific
  cases; the notebook guards the invariants. Both must be green.
- **No runtime dependencies.** Dev/test tooling must be
  `runtime: false`. Visualisation dependencies enter through a
  notebook's own `Mix.install`, never through `mix.exs`.
- **No suppressions to make tooling green.** No
  `@dialyzer {:nowarn_function, ...}`, no `# credo:disable-for-*`. Fix
  the finding or explain why it should stand.
- **Keep it small.** One struct, one propagator, and as few notebooks
  as the distinct concepts demonstrated actually require. This is a
  demonstration, not a simulator. Do not add J2, drag, or eccentricity;
  do not add a behaviour, a protocol, or a plugin system; do not
  introduce absolute latency or memory thresholds, which have no oracle
  and are not invariants.

## The checkpoint cycle

```sh
bin/run_checkpoint                  # the gate: exits 0 only if every invariant holds
bin/run_checkpoint --timeout 30     # while functions still raise, pass a short one
elixir bin/checkpoint_history.exs   # every run so far, as a trend
```

`bin/run_checkpoint` deploys the specification notebook through
Livebook's own execution path and converts its report into an exit
code, so the gate runs the actual notebook rather than an extraction of
it. It takes an optional notebook path and defaults to the
specification. Any notebook that loads `livebooks/checkpoint.exs`,
declares its checks with `Checkpoint.init/1`, records them with
`Checkpoint.check/3` and ends with `Checkpoint.complete/0` is gated the
same way — that is the seam for adding an invariant later without
touching the tooling.

Three outcomes are distinguishable, deliberately:

| Report state | Means |
|---|---|
| Sentinel present, all checks `ok: true` | Every invariant holds. Exit 0. |
| Sentinel present, some check `ok: false` | The code ran; the physics is wrong. The named check says which. |
| No sentinel | Evaluation never reached the last cell — usually an uncaught exception, expected while functions still raise. A timeout looks identical, so check elapsed time before hunting an exception that isn't there. |

A failing check does not abort the run, so one pass reports on every
invariant rather than stopping at the first. Each record carries
`expected`, `actual`, `tolerance` and `unit`, so a failure tells you how
far off you are and in which direction.

Every run is kept under `reports/<notebook name>/`, named by UTC start
time, alongside a `.diff` capturing the working tree that produced it.
**Reports are committed, in full, and must not be pruned or
hand-picked** — a selected subset is weaker evidence than none, because
a reader applying rigour would rightly ask what was left out.
`bin/checkpoint_history.exs` renders the series: rows are invariants,
columns are runs. Consult it after refactoring, not only after adding
something. An invariant that was passing and now fails is the exact
regression this repository exists to make visible, and it is far easier
to see in a series than in a single run.

Requires Livebook on `PATH` (`mix escript.install hex livebook`).
Toolchain versions are pinned in `.tool-versions`.

## Verifying your work

```sh
mix compile           # must be warning-free
mix format --check-formatted
mix credo --strict    # must be clean
mix dialyzer          # must be clean
mix test
bin/run_checkpoint    # the gate
```

Two of these are expected to be red *while* you work, and neither is
cause for alarm or suppression: dialyzer reports `no_return` for every
function that only raises, and `mix test` has nothing to run until the
test layer exists.

**The notebook's assertions are the definition of done.**
