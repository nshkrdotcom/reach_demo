# RD-06 — Missing per-file diagnostics for invalid or absent source inputs

**Supports proposed issue 106.** This project is independent of the original RD-01–04 reproductions.

`fixtures/valid.ex` parses, while `fixtures/invalid.ex` deliberately does not. The default full-SDG and secondary `source_only` comparisons show that adding the invalid file leaves the project graph unchanged, with no machine-readable per-file error in the returned `%Reach.Project{}`. An isolated missing-path probe also passes an absent `fixtures/does_not_exist.ex` directly to Reach and records the same omission. The `.txt` unknown-extension probe is separate, not essential to the claim.

`ExUnit.CaptureLog` and `ExUnit.CaptureIO` are started for standalone `mix run` execution. Logged text is not a substitute for structured diagnostics in the return value. The optional `return_diagnostics: true` probe uses `apply/3` for compatibility with Elixir 1.18–1.20 and to avoid a compile-time type warning.

Run from this project directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

Optional CLI observation: `mix reach.otp fixtures` reports `Analyzing 2 file(s)` for the requested `.ex` paths without identifying that the invalid one was dropped; the count refers to requested files, not successfully parsed files.

**Recorded evidence:** [`evidence/rd-06.json`](evidence/rd-06.json) has status `reproduced` and includes the invalid-syntax and nonexistent-path comparisons. Future-fix tests are excluded by default. Regenerate the report only if the fixtures or investigation code change.
