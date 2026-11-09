# RD-05 — Resolved plugin list lost during per-module SDG construction

**Upstream draft 105; original proposal RCH-01.** Standalone project; no
changes to the four original `reach_demo` reproduction projects.

`ProbePlugin` emits two uniquely labeled edges: a direct `analyze/2` edge
and a project `analyze_project/3` edge. Both endpoints are real IR nodes.
The direct SDG and project hook are independent **positive controls**; the
project graph is inspected with explicit plugins and both
`retain_module_sdgs` settings. `plugins: []` is a custom-plugin negative
control, **not** proof that no host plugin ran.

A host ExUnit probe records automatic plugin **selection only**. The shipped
`Reach.Plugins.ExUnit.analyze/2` emits `[]`, so its detection is not evidence
of an unwanted local graph edge. A separate Ecto example checks a direct
`Reach.Plugins.Ecto.analyze/2` positive edge (`:ecto_cast_params`) against an
inferred **full-SDG** project build, with `source_only` selection alongside it.
A different fixture has `:ecto` only in an inert target `mix.exs` and **no
`Ecto` source marker**, testing dependency inference separately. Target
`mix.exs` files are read, never executed.

Run from this project directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

Inspect `evidence/rd-05.json`. It has the original RD evidence schema and
Hex Reach provenance. The **headline status** is decided by ProbePlugin's
positive controls; the additional inferred Ecto results are independent
observations that must have their own controls before being claimed as bugs.
Expected-fix tests are excluded by default. Failed runs write a `.failure.json`
diagnostic. Recorded runtime evidence is committed in `evidence/rd-05.json`.
