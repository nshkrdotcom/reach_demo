# reach_demo

Eight small, standalone Elixir/Mix projects exploring Reach 2.8.4's source and OTP analyses. Each has its own fixtures, tests, reproduction script, and recorded evidence.

- **[Node ID stability](monorepo/01_node_id_stability/)** — Node IDs across source revisions and file order; existing upstream issue 08.
- **[Message and reply matching](monorepo/02_message_reply_coupling/)** — GenServer calls, replies, and message-payload edges; existing issues 04–07.
- **[Supervisor detection](monorepo/03_supervision_semantics/)** — Supervisors and child relationships; existing issues 01–03.
- **[Macros and BEAM](monorepo/04_macro_source_beam_alignment/)** — Authored macro invocations and generated functions; existing issue 09.
- **[Plugin propagation](monorepo/05_plugin_sdg_propagation/)** — Project-selected plugins missing from per-module SDGs; draft 105.
- **[Parse diagnostics](monorepo/06_parse_diagnostics/)** — Syntactically invalid requested files omitted without structured diagnostics; draft 106.
- **[Framework-edge precision](monorepo/100_framework_edge_precision/)** — Phoenix and Ecto precision probes; drafts 107 and 108. Also includes an Ash investigation, which is not asserted as a proven runtime dispatch error.
- **[gen_statem transitions](monorepo/101_gen_statem_transitions/)** — Callback-mode uncertainty and duplicate CLI reporting; drafts 109 and 110. Other modeled semantics are observations, not claimed defects.

Each folder is an independent Mix project. With Elixir 1.18+ and Erlang/OTP installed, run `mix deps.get`, `mix test`, and `mix run scripts/reproduce.exs` from its directory. Outputs are in `evidence/`. Investigative evidence can have a status of `inconclusive` while still containing specific, repeatable observations; consult each issue for the precise claim.
