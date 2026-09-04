# Project Instructions

## Summary

Build an orbital mechanics implementation based on Hill–Clohessy–Wiltshire
(HCW) relative motion, satisfying the invariants stated in
`livebooks/hcw_orbital_mechanics.livemd`, and demonstrating the resulting
orbits visually.

**Read `AGENTS.md` first.** It carries the rules that govern this
repository — the cardinal rule, the direction of dependency, the domain
traps that produce plausible-looking wrong answers, and the constraints
on dependencies and tooling. This file does not repeat them; it says what
to build and how to check it.

## The deliverable

A working `Plumbline.Dynamics.HCW` such that the notebook renders **both**
of its trajectory plots correctly:

1. **The 2:1 ellipse** — the drift-free in-plane orbit, plotted
   along-track against radial. A correct implementation closes the
   ellipse; one with broken Coriolis coupling draws a spiral, and the
   difference is visible without reading a number.
2. **The circular relative orbit** — the `z₀ = √3·x₀` case, plotted in
   its own tilted plane. A correct implementation closes a circle of
   radius `2x₀`.

Both plots already exist in the notebook. They do not render today
because every function in `lib/plumbline/dynamics/hcw.ex` is a stub that
raises. Filling those in is the task.

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
bin/run_checkpoint                      # runs the notebook headlessly, exits 0 only if every invariant holds
elixir bin/checkpoint_history.exs       # every run so far, as a trend
```

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
| No sentinel | Evaluation aborted — an uncaught exception, not an assertion failure. Expect this while functions still raise. |

A failing check does not abort the run, so one pass reports on every
invariant rather than stopping at the first.

Every run is kept, under `reports/` (gitignored), named by UTC start
time. `bin/checkpoint_history.exs` renders them as a table — rows are
invariants, columns are runs, oldest first — so you can see an
invariant getting fixed, and, just as importantly, see one that was
passing start to fail again. Check it after a refactor, not just after
a feature: a change that fixes one invariant while quietly breaking
another is precisely the failure mode this whole repository exists to
catch.

Also run the checks in `AGENTS.md`'s "Verifying your work" section —
compile warnings, formatting, credo, dialyzer, `mix test`, and
`verify_spec.exs`. The notebook and those checks guard different things
and both must be green.

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
- `analytic/3` is an independent oracle. It must not call
  `derivative/2`, `step/3`, or `propagate/4` — the notebook cross-checks
  the numerical trajectory against it, and that check is worthless if
  they share code.
- Use RK4 for `step/3` and `propagate/4`, not the closed-form state
  transition matrix. With the exact solution, periodicity holds to
  machine epsilon by construction and the assertions stop meaning
  anything.
