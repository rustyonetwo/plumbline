# Plumbline

<!-- TODO(rusty): first-draft README, written before the implementation
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

Full explanation of the pattern, the rules this repository follows,
and the specific physics traps a naive implementation falls into: see
[`AGENTS.md`](AGENTS.md).

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
| `livebooks/hcw_orbital_mechanics.livemd` | **The specification.** Physics narrative, the equations of motion, three invariants derived in full, and executable assertions. Written before any code. |
| `lib/plumbline/dynamics/hcw.ex` | The implementation, written to satisfy the notebook. |
| `verify_spec.exs` | A standalone script (no project, no dependencies) that independently checks the notebook's own numeric claims against the closed-form solution. Does not test `lib/`. |
| `test/` | Unit tests descending from the notebook's invariants — edge cases and boundary values the property assertions don't naturally exercise. |
| `AGENTS.md` | The rules: what this repository is, the cardinal rule (never edit the notebook to make an assertion pass), and the specific domain traps a plausible-looking implementation can fall into. |

## Running it

Toolchain versions are pinned in [`.tool-versions`](.tool-versions)
(managed with [asdf](https://asdf-vm.com)):

```sh
asdf install
mix deps.get
mix test
elixir verify_spec.exs   # independent check of the notebook's own claims
```

To run the notebook itself, open `livebooks/hcw_orbital_mechanics.livemd`
in [Livebook](https://livebook.dev). Until the implementation lands,
its assertions will fail — that's expected, see Status above.

## License

MIT — see [`LICENSE`](LICENSE).
