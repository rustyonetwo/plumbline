# Plumbline

<!-- TODO: first-draft README, written before the implementation
     exists. Needs a real pass once HCW.ex is filled in — at minimum:
     confirm the quickstart commands actually work end-to-end, add the
     talk/video link once ElixirConf happens, reconsider the "status"
     section once it's not red anymore. Don't let this go stale. -->

**Plumbline** is a small, complete demonstration of **proof-driven
development**: a Livebook notebook states the mathematical invariants
of a system first, as narrative, rendered mathematics, and executable
assertions — before any implementation exists — and the implementation
is written to satisfy it.

The domain is orbital mechanics: relative motion between two
spacecraft in nearby orbits (the Hill–Clohessy–Wiltshire equations).
Nobody in an audience can eyeball-verify orbital mechanics, which is
the point — the notebook has to actually prove it, not just look
plausible.

The physics, the invariants and their derivations are all in the
specification notebook itself — deliberately, since a repository about
single-source-of-truth should not keep a second copy of its own
subject. For the rules this repository works under, and how the
notebook is run as a gate, see [`AGENTS.md`](AGENTS.md).

## Status

**The notebook is complete. The implementation is not — deliberately,
right now.**

`livebooks/hcw_orbital_mechanics.livemd` states three invariants and
asserts them executably. `lib/plumbline/dynamics/hcw.ex` is a stub;
every function raises. That's the intended state of a spec-first
commit: the specification is written, executable, and *failing*, and
stays that way until an implementation is written against it. If
you're reading this after that's landed, this section is stale —
check the notebook itself, which is always current.

## What's here

| Path | What it is |
|---|---|
| `livebooks/hcw_orbital_mechanics.livemd` | **The specification.** Physics narrative, the equations of motion, three invariants derived in full, and executable assertions. Written before any code. Contains no plotting: a notebook that governs invariants is not also a deliverable. |
| `livebooks/hcw_visualisation.livemd` | Draws the relative orbits. Judges nothing, gates nothing, and is free to change without re-reviewing the specification. |
| `bin/run_checkpoint` | Runs a checkpoint notebook headlessly and turns its report into an exit code. |
| `lib/plumbline/dynamics/hcw.ex` | The implementation, written to satisfy the notebook. |
| `test/` | Unit tests descending from the notebook's invariants — edge cases and boundary values the property assertions don't naturally exercise. |
| `AGENTS.md` | The bounds an agent works within — the cardinal rule (never edit the notebook to make an assertion pass), what may and may not be changed, and the checkpoint cycle. Contains nothing about the physics; that lives in the notebook. |
| `instructions.md` | The brief handed to the implementing agent: the task, where things are, and what "done" means. |

## Running it

Toolchain versions are pinned in [`.tool-versions`](.tool-versions)
(managed with [asdf](https://asdf-vm.com)):

```sh
asdf install
mix deps.get
mix test
bin/run_checkpoint       # runs the specification notebook as a gate
```

To run the notebook itself, open `livebooks/hcw_orbital_mechanics.livemd`
in [Livebook](https://livebook.dev). Until the implementation lands,
its assertions will fail — that's expected, see Status above.

## License

MIT — see [`LICENSE`](LICENSE).
