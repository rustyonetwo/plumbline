# Project Instructions

## Summary

Build an orbital mechanics implementation based on Hill–Clohessy–Wiltshire
(HCW) relative motion, satisfying the invariants stated in
`livebooks/hcw_orbital_mechanics.livemd`, and demonstrating the resulting
orbits visually.

**Read `AGENTS.md` first.** It carries the rules that govern this
repository — the cardinal rule, the direction of dependency, the domain
traps that produce plausible-looking wrong answers, and the constraints
on dependencies and tooling. It is the authority; where this file and
`AGENTS.md` disagree, `AGENTS.md` wins. This file says what to build and
how to check it.

## The deliverable

A working `Plumbline.Dynamics.HCW` that satisfies every invariant in
`livebooks/hcw_orbital_mechanics.livemd`, and which consequently makes
`livebooks/hcw_visualisation.livemd` draw **both** trajectories:

1. **The 2:1 ellipse** — the drift-free in-plane orbit. A correct
   implementation closes the ellipse; one with broken Coriolis coupling
   draws a spiral, and the difference is visible without reading a
   number.
2. **The circular relative orbit** — the `z₀ = √3·x₀` case, viewed in
   its own tilted plane. A correct implementation closes a circle of
   radius `2x₀`.

Both plots already exist. Neither draws today because every function in
`lib/plumbline/dynamics/hcw.ex` is a stub that raises. Filling those in
is the whole task — you should not need to write any plotting code, or
to touch either notebook.

These are two deliverables with two different kinds of proof. The
invariants are **gated**: `bin/run_checkpoint` passes or fails on them,
and that verdict needs no human. The plots are **not gated** —
`hcw_visualisation.livemd` never calls `Checkpoint.complete/0`, so the
checkpoint script cannot run it, and someone has to look at them. Do
not report the second as done on the strength of the first.

### The two notebooks are not the same kind of thing

`hcw_orbital_mechanics.livemd` is the **specification**: invariants,
their derivations, and the executable assertions that check them. It is
the wall you are working against, it changes rarely, and CI runs it as
a gate. It contains no plotting and depends on nothing but this project.

`hcw_visualisation.livemd` **draws** relative orbits and judges nothing.
It is not part of the gate.

**On verifying the visual part.** `bin/run_checkpoint` runs headlessly
and emits JSON; it renders nothing, so it cannot confirm a plot looks
right. What it *can* confirm is the numbers those plots are drawn from —
closure after one period, and a constant radius on the circular orbit —
and correct numbers are necessary but not sufficient. The
`tilted_radial_km` projection in `hcw_visualisation.livemd`, and the
axis bindings under it, are computed in that notebook rather than in
`lib/`, so they sit outside the gate entirely: every number can be
right while the picture is wrong — a swapped axis or a mistyped
coefficient looks like data, not like a bug. Treat the checkpoint as
the gate on the physics, and rendering as a separate human step. If you
cannot open the visualisation notebook in Livebook yourself, say so in
your summary rather than claiming the visual deliverable is confirmed.

## Method

The notebook is the specification and the checkpoint. It is not a test
file, and it is not to be edited to make an assertion pass — see the
cardinal rule in `AGENTS.md`.

Work in this order:

1. **Read the notebook end to end** before writing any Elixir. It
   teaches the domain, derives all three invariants in full, and states
   the interface contract (section 4) that your implementation must
   expose.
2. **Implement against it**, iterating with `bin/run_checkpoint` (below).
3. **Unit tests afterwards**, descending from the invariants — edge
   cases, error paths, and boundary values that the property assertions
   don't naturally exercise. Tests never precede the invariants they
   descend from; this is proof-driven development, not test-driven
   development, and the ordering is the point of the exercise.

## The checkpoint loop

```sh
bin/run_checkpoint                        # runs the specification notebook headlessly; exits 0 only if every invariant holds
bin/run_checkpoint --timeout 30           # same, with a 30s timeout
elixir bin/checkpoint_history.exs         # every run so far, as a trend
```

`bin/run_checkpoint` takes an optional notebook path and defaults to the
specification notebook, deploying only that one. Any notebook that loads
`livebooks/checkpoint.exs`, declares its checks with `Checkpoint.init/1`,
records them with `Checkpoint.check/3` and ends with
`Checkpoint.complete/0` can be gated the same way — which is how a
further invariant would be added later, without touching the script.

A run that reaches the last cell stops as soon as it does — whether its
checks passed or failed, since the completion sentinel is written either
way. Those runs are quick. A run that *aborts* leaves no sentinel to
wait for and pays the full timeout, so while functions still raise, pass
a short one.

This deploys the real notebook through Livebook's own execution path
(`LIVEBOOK_APPS_PATH`) — it is not an extraction or a reimplementation of
the notebook's cells. Each assertion appends a JSON record to a report
file, the last cell writes a completion sentinel, and
`bin/check_report.exs` turns that report into an exit code.

The report is a **scorecard, not a pass/fail bit**. Each record carries
`expected`, `actual`, `tolerance`, and `unit`, so a failure tells you how
far off you are and in which direction. Use that signal to iterate —
`actual: 37.699` against `expected: 0.0` in kilometres, for instance, is
not a generic failure, it is a specific and well-documented bug (see the
drift-free condition trap in `AGENTS.md`).

Three outcomes are distinguishable, deliberately:

| Report state | Means |
|---|---|
| Sentinel present, all checks `ok: true` | Every invariant holds. Exit 0. |
| Sentinel present, some check `ok: false` | Code ran; physics is wrong. The named check tells you which. |
| No sentinel | The run never reached the last cell. Usually an uncaught exception — expect this while functions still raise — but a timeout looks identical, so check the reported elapsed time before hunting for an exception that isn't there. |

A failing check does not abort the run, so one pass reports on every
invariant rather than stopping at the first.

Every run is kept, under `reports/<notebook name>/`, named by UTC start
time — per notebook, so a second checkpoint notebook keeps its own
history rather than interleaving with this one. Reports are committed
and are not pruned; do not delete them to tidy up, and do not be
alarmed by a long series of failures, which is what the early part of
this work is supposed to look like.

Each run also writes a `.diff` next to its report — same basename —
holding the working tree that produced it, captured before evaluation.
You do not have to do anything with it; it exists so a run's result can
be read against the code that produced it. The report's last line
points at it.
`bin/checkpoint_history.exs` renders them as a table — rows are
invariants, columns are runs, oldest first — so you can see an
invariant getting fixed, and, just as importantly, see one that was
passing start to fail again. Check it after a refactor, not just after
a feature: a change that fixes one invariant while quietly breaking
another is precisely the failure mode this whole repository exists to
catch.

Also run the checks in `AGENTS.md`'s "Verifying your work" section —
compile warnings, formatting, credo, dialyzer, `mix test`, and
`verify_spec.exs`. The notebook and those checks guard different things,
and both must be green by the time you are done.

Two of them are expected to be red *while* you work, and neither is
cause for alarm or for suppression. Dialyzer reports `no_return` for
every function that still only raises; those clear as the functions
start returning. `mix test` reports nothing to run until you reach step
3, since the test layer doesn't exist yet.

### Environment prerequisites

The checkpoint loop needs Livebook available on `PATH`:

```sh
mix escript.install hex livebook
```

Toolchain versions are pinned in `.tool-versions`. If you use asdf, make
sure a version is resolvable from outside the project directory too
(`asdf set --home erlang <version>` and likewise for elixir) — Livebook
spawns runtimes whose working directory is not this repository, and an
unresolvable shim there fails in a way that is hard to read.

## Constraints on your work

- **Do not run git commands.** No commits, branches, pushes, or pulls.
  Stop and ask if something seems to require one.
- Do not edit the notebook to make an assertion pass. If you become
  convinced an assertion is itself wrong, stop and say so, explaining
  which claim you believe is incorrect and why.
- **Do not edit the notebook's prose either.** The narrative and the
  derivations are human-authored and human-verified. Some of it goes
  stale as you work — section 5 opens by saying the implementation is a
  stub that raises, which stops being true the moment you finish. Leave
  it, and say what has gone stale in your summary instead of correcting
  it yourself. The same goes for `README.md`.

Two rules from `AGENTS.md` are worth having in front of you while
writing this particular implementation, because both are easy to
violate by accident and neither shows up as a failing check — the
notebook still passes if you get them wrong. They are stated in full,
authoritatively, in `AGENTS.md`; read them there.

- `analytic/3` is an **independent oracle** and must not call
  `derivative/2`, `step/3`, or `propagate/4`.
- **Use RK4** for `step/3` and `propagate/4`, not the closed-form state
  transition matrix.
