# RD-06 — Per-file parse/build diagnostics missing from project results

**Supports upstream draft 106.** Standalone Mix project, independent of the four original repros.

`fixtures/valid.ex` parses, while `fixtures/invalid.ex` deliberately contains invalid syntax. The primary default full-SDG and secondary source-only comparisons confirm whether the invalid source is silently dropped. A **separate missing-path probe** passes an absent `fixtures/does_not_exist.ex` path directly to Reach without using the `Support.fixture!/1` helper. The explicit non-Elixir `.txt` side probe remains separate and is not essential to the claim.

`ExUnit.CaptureLog`/`ExUnit.CaptureIO` are started for standalone `mix run` execution. Log output is not equivalent to per-file structured diagnostics in the returned `%Reach.Project{}`. A hypothetical `return_diagnostics: true` API is probed with `apply/3` to avoid the Elixir 1.20 compile warning while supporting Elixir >= 1.18.

Run from this project directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
mix reach.otp fixtures
```

The last command is an **optional manual CLI confirmation**. It may print `Analyzing 2 file(s)` even when the invalid file is omitted; that count refers to requested paths, not successfully parsed files.

See [`evidence/rd-06.json`](evidence/rd-06.json). Regenerate it after this patch. Future-fix tests remain excluded by default.
