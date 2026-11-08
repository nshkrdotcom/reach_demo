# Node ID stability

This example checks what happens to Reach 2.8.4's graph node IDs when the source code changes. The function in [`target_before.ex`](fixtures/target_before.ex) still does the same thing in [`target_after.ex`](fixtures/target_after.ex), but adding an unrelated function before it changes all six matched node IDs. Adding a comment changes none of them; changing source-file order changes all six again. Separately analyzed BEAM modules also reuse numeric IDs, though no broken graph merge was demonstrated. These IDs are useful within an analysis, but shouldn't be assumed to identify the same code across revisions.

Run it from this directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

The recorded comparisons are in [`evidence/rd-01.json`](evidence/rd-01.json).
