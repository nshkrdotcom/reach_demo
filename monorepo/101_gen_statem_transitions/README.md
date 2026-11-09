# INV-101 — `gen_statem` transition investigation (RCH-10)

**Supports upstream draft 109 (duplicate CLI transition/event rows) and draft 110 (dynamic callback-mode uncertainty).** `monorepo/101` is a reproduction-project identifier, not GitHub draft 101. It does not change the original four projects.

Seven inert, source-parsed fixtures exercise `:state_functions`, `:handle_event_function`, `[:handle_event_function, :state_enter]`, `:keep_state` / `:repeat_state`, postponed events and timers, guards, and a truly dynamic callback mode without either mode literal.

The report records two distinct, supported findings:

1. `Reach.OTP.GenStatem.analyze/1` returns two transitions for each basic literal-mode fixture; `mix reach.otp <same-file> --format json` returns eight entries, each transition repeated exactly four times. Six of seven fixtures contain transitions and show the same fourfold CLI multiplicity. The CLI commands exit `0` with valid JSON.
2. For `fixtures/dynamic_mode.ex`, `callback_mode/0` reads application configuration rather than returning a source literal. Reach reports `state_functions` with no states or transitions. The Reach 2.8.4 source confirms that its mode detector defaults to `state_functions` when neither callback-mode atom is found. This is a false-precision/unknown-mode reporting issue, **not** a demand for Reach to run application configuration during static analysis.

Other differences (state-functions `nil` triggers, `keep_state` / `repeat_state` self-loops, state-enter events, postponement and guard constraints) remain **observations, not filed defects**. The combined INV-101 report retains `status: inconclusive` for that broader scope; it does not negate the two specific findings above.

Run from this project directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

The script runs the public library analyzer and all seven independent `mix reach.otp <fixture> --format json` commands. It records the CLI exit codes, decoded output, and fixture checksums in [`evidence/inv-101.json`](evidence/inv-101.json). No upstream-fix behavior is claimed.
