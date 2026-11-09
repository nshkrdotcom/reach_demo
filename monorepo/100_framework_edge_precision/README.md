# INV-100 — Phoenix, Ecto, Ash framework-edge investigation

**Supports issue drafts 107 (Phoenix fallback scope) and 108 (Ecto candidate changeset flow).** `monorepo/100` is a reproduction-project identifier, not a GitHub issue number.

`fixtures/phoenix/with_fallback.ex` establishes an action and unrelated utility in one file; `without_fallback.ex` is the negative control. The added `fixtures/phoenix/extra.ex` declares *two different controllers* and *two separate fallback declarations* in the same file. Reach 2.8.4's local Phoenix hook connects an error from controller B to controller A's first fallback. This directly tests file-level rather than controller-level scoping. It uses **parsed IR**, not runtime Phoenix dispatch, and one controller per file is more typical.

The Ecto fixture `paired.ex` tests both a cast result actually passed to a `TestRepo.insert/1` and an unused cast result in the same function as an unrelated write. Reach's Ecto hook generates a candidate changeset-flow edge in both cases. `FakeRepo` tests name-suffix detection; neither fake Repo is a compiled `Ecto.Repo` module. This is a **precision enhancement**, not a claim that Reach promises exact data-dependence.

Separate Ash project-hook experiments are preserved as observations, not part of issues 107/108. The report remains **overall `inconclusive`** because the investigation contains intentional heuristic cases; `comparisons` records each specific observed precision finding with its own `status: reproduced` when the assertion holds.

Run from this project directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

The evidence report is [`evidence/inv-100.json`](evidence/inv-100.json). Re-run after adding fixtures so its SHA-256 inputs and observations include `extra.ex`. No original reproduction projects are modified.
