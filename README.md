# reach_demo

Four small, standalone Elixir projects exploring how Reach 2.8.4 analyzes code. Each has its own examples, tests, and reproduction script.

- **[Node ID stability](monorepo/01_node_id_stability/)** — What happens to node IDs when code or file order changes.
- **[Message and reply matching](monorepo/02_message_reply_coupling/)** — How it connects calls, replies, and message payloads.
- **[Supervisor detection](monorepo/03_supervision_semantics/)** — How it finds supervisors and their children.
- **[Macros and BEAM](monorepo/04_macro_source_beam_alignment/)** — How macro-generated functions map back to source code.

Each folder is a separate Mix project. With Elixir 1.18+ and Erlang/OTP installed, open the project you want to run and use `mix deps.get`, `mix test`, and `mix run scripts/reproduce.exs`. Its results are saved under `evidence/`.
