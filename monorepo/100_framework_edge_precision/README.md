# INV-100 — Phoenix, Ecto, and Ash framework-edge investigation

**Supports proposed issues 107 (Phoenix fallback scoping) and 108 (Ecto candidate changeset flow).** Directory number `100` is an investigation ID, not a GitHub issue number.

## Findings covered by issues

**Phoenix (107):** `fixtures/phoenix/extra.ex` declares two controllers with distinct `action_fallback` directives in a single source file. Reach 2.8.4's `Reach.Plugins.Phoenix.analyze/2` connects `Demo.CtrlB.index/2`'s error tuple to controller A's fallback instead of controller B's own. The investigation directly tests the plugin's local hook. `with_fallback.ex` and `without_fallback.ex` provide the other positive and negative controls. This demonstrates file-scoped edge generation in parsed IR, **not** actual runtime Phoenix dispatch; putting one controller per file is more typical.

**Ecto (108):** `fixtures/ecto/paired.ex` contains a cast result passed into `TestRepo.insert/1` and a same-function cast whose result is unused by its `insert/1` call. Reach labels both `{:ecto_changeset_flow, :cast}`. The plugin uses a same-function heuristic: this is a request to distinguish candidate from demonstrated dataflow, not a claim that Reach promises exact flow. `FakeRepo` exercises suffix-based Repo-name detection; the mock repo modules are not verified Ecto repos.

**Ash:** The additional multi-module, project-hook probes are retained as observations. They are **not** the basis for issues 107/108 and do not establish runtime Ash dispatch behavior.

Run from this project directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

**Recorded evidence:** [`evidence/inv-100.json`](evidence/inv-100.json) includes `extra.ex` and contains the individual `phoenix_cross_controller_fallback` and `ecto_same_function_candidate_flow` findings as `status: reproduced`. Its overall `inconclusive` status is intentional because other heuristic observations remain unclassified. The evidence is already generated; rerun only if you modify the inputs or investigation.
