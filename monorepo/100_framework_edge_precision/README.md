# INV-100 — Framework edge-precision investigation (RCH-09)

**Investigation, not a confirmed bug or a GitHub issue draft.** The
`100_framework_edge_precision` directory has no relation to draft 101.

Three separate source-only Reach 2.8.4 probes:

- **Phoenix:** a module-level `action_fallback` plus controller and unrelated
  utility errors, compared with a no-fallback control. The fallback rule is
  in `Reach.Plugins.Phoenix.analyze/2` (local hook), **not** the Phoenix
  `analyze_project/3` plug-chain hook. Only the local hook is used for this
  hypothesis.
- **Ecto:** one real cast-to-write dataflow, one same-function unused cast,
  a no-cast control, and a `FakeRepo` suffix-only decoy. The suffix is
  heuristic; no fixture claims that `FakeRepo` actually uses `Ecto.Repo`.
- **Ash:** valid Ash 3 domain code-interface syntax is used in
  `resources do; resource ResourceA do; define :create_user, ...; end; end`.
  Separate resource modules include an **unregistered** same-named action
  (ResourceB) and a different-action control. The project-level
  `analyze_project/3` hook is invoked directly and compared with the merged
  graph. The fixture syntax follows Ash's published DSL, but framework
  dependencies are intentionally **not compiled or executed**.

Run from this project directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

Read `evidence/inv-100.json` and check each reported source/target before
claiming a false edge. The result deliberately stays `inconclusive` until
observed edges and their semantic assumptions are validated. The existing
four reproduction projects remain unchanged.
