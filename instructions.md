# Project Instructions

## The task

Implement `Plumbline.Dynamics.HCW` so that it satisfies every invariant
in `livebooks/hcw_orbital_mechanics.livemd`, then write unit tests
descending from those invariants.

That notebook is the specification. Read it first, in full. It states
the physics, derives the invariants, defines the interface contract you
must expose, and asserts all of it executably. Everything you need to
build this is in there; nothing outside it is authoritative.

**Read `AGENTS.md` before starting.** It carries the bounds you work
within and the checkpoint cycle you iterate against.

## Where things are

| Path | What it is |
|---|---|
| `livebooks/hcw_orbital_mechanics.livemd` | The specification. Authoritative. Do not edit. |
| `livebooks/hcw_visualisation.livemd` | Draws the orbits. Gates nothing. Do not edit. |
| `lib/plumbline/dynamics/hcw.ex` | What you implement. Currently a stub that raises. |
| `test/` | Where your unit tests go. Empty today. |
| `bin/run_checkpoint` | The gate. See `AGENTS.md`. |

## Done means all of

1. `bin/run_checkpoint` exits 0 — every invariant in the specification
   notebook holds.
2. `mix test` passes, with tests that descend from those invariants and
   cover what the property assertions do not: edge cases, error paths,
   boundary values.
3. `mix compile` is warning-free, and `mix format --check-formatted`,
   `mix credo --strict` and `mix dialyzer` are all clean.
4. `livebooks/hcw_visualisation.livemd` draws its trajectories when
   opened. You should not need to write any plotting code — the plots
   exist and are waiting on a working implementation.

On (4): the checkpoint renders nothing, so it cannot confirm a plot
looks right, and the visualisation notebook computes its own
projections and axis bindings outside the gate. Correct numbers are
necessary but not sufficient there. If you cannot open the notebook in
Livebook yourself, say so in your summary rather than reporting the
visual deliverable as confirmed.
