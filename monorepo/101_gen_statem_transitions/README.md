# INV-101 — `gen_statem` callback modes and transition reporting

**Supports issue drafts 109 (repeated transition/event records) and 110 (callback-mode precision).** `monorepo/101` is a reproduction-project identifier, not GitHub issue 101.

Eight source-parsed fixtures cover both standard callback modes, state-enter options, postponed/timeouts, guards, keep/repeat, dynamic modes, and **`attr_mode.ex`**, which returns a statically declared `@mode :handle_event_function` from `callback_mode/0`.

Two focused observations:

1. For `state_functions_basic.ex`, `Reach.OTP.GenStatem.analyze/1` produces two distinct transitions from raw IR roots, but the same analyzer produces eight when passed the pre-flattened `[module | all_nodes(module)]` input assembled by `Reach.OTP.Analysis`. The JSON `mix reach.otp` output also contains eight instead of two; this tests a library-level accumulation cause, not simply a CLI formatter glitch.
2. For `attr_mode.ex`, Reach reports `state_functions` with no transitions despite the callback mode being encoded in the module attribute. A second fixture using `Application.fetch_env!` tests genuinely unresolved runtime configuration; such cases should be reported as uncertain rather than definitely `state_functions`.

Other semantics (state-functions nil triggers, keep/repeat state loops, state-enter, timers, guard feasibility) remain **observations rather than alleged bugs**. The overall status stays `inconclusive` for that broader scope; the specific results have their own `status: reproduced` assertions in `comparisons`.

Run from this project directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

The script runs direct library analysis and `mix reach.otp <fixture> --format json` for **each of the eight files**. Evidence: [`evidence/inv-101.json`](evidence/inv-101.json). **Regenerate it before filing** so the committed input hashes and cases include `attr_mode.ex`.
