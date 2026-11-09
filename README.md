# reach_demo

Eight standalone Elixir/Mix projects reproducing or investigating the behavior of **Reach 2.8.4**. Each has its own fixtures, tests, reproduction script, and recorded evidence. Project directory numbers are **not** GitHub issue numbers.

- **[01 — Node ID stability](monorepo/01_node_id_stability/)** — Source/BEAM node IDs and cross-run identity; upstream issue 08.
- **[02 — Message/reply coupling](monorepo/02_message_reply_coupling/)** — GenServer calls, replies, message payloads, and callback scoping; upstream issues 04–07.
- **[03 — Supervision semantics](monorepo/03_supervision_semantics/)** — Supervisor detection and child extraction; upstream issues 01–03.
- **[04 — Macro/BEAM alignment](monorepo/04_macro_source_beam_alignment/)** — Authored macro invocations and generated functions; upstream issue 09.
- **[05 — Plugin SDG propagation](monorepo/05_plugin_sdg_propagation/)** — Selected plugins not forwarded to module SDGs; proposed issue 105.
- **[06 — Parse diagnostics](monorepo/06_parse_diagnostics/)** — Invalid or missing requested source files omitted without structured project diagnostics; proposed issue 106.
- **[100 — Framework-edge precision](monorepo/100_framework_edge_precision/)** — Phoenix fallback scoping and Ecto candidate changeset flow; proposed issues 107–108. Separate Ash observations are not claimed as bugs.
- **[101 — gen_statem transitions](monorepo/101_gen_statem_transitions/)** — Duplicate transition reporting and callback-mode misclassification; proposed issues 109–110. Other `gen_statem` observations remain investigative.

All eight are independent Mix projects. With Elixir 1.18+ and Erlang/OTP installed, run `mix deps.get`, `mix test`, and `mix run scripts/reproduce.exs` from the selected project directory. Check its `evidence/` directory for the recorded JSON and Reach/Elixir/OTP provenance.

The framework (`INV-100`) and `gen_statem` (`INV-101`) reports can have an **overall** status of `inconclusive` while their specific, tested findings have `status: reproduced` in `comparisons`. The relevant issue text states the narrower claim; a static-analysis edge does not establish runtime behavior.
