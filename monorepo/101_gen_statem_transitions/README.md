# INV-101 — `gen_statem` callback modes and transition reporting

**Supports proposed issues 109 (duplicate transition reporting) and 110 (callback-mode misclassification).** Directory number `101` is an investigation ID, not GitHub issue 101.

Eight source-parsed fixtures cover the two standard callback modes, state-enter options, guards, postponed events and timers, keep/repeat behavior, dynamic callback modes, and `fixtures/attr_mode.ex` (which returns the statically declared `@mode :handle_event_function`).

## Findings covered by issues

**Duplicate reporting (109):** The same ordinary state machine yields two transitions when `Reach.OTP.GenStatem.analyze/1` receives raw IR roots but eight when it receives the flattened input used by `Reach.OTP.Analysis`. The `mix reach.otp` JSON result also repeats them. This is a library-level traversal/aggregation issue, not merely a CLI formatter issue; the fourfold multiplicity is specific to the demonstrated structure.

**Callback mode (110):** `attr_mode.ex` is statically resolvable to `:handle_event_function`, yet Reach reports `state_functions` with no transitions. The independent `dynamic_mode.ex` case exercises a genuinely runtime-dependent mode, for which an explicit unknown/uncertain result would be preferable to a definite fallback.

Other `gen_statem` observations are retained for context, **not** presented as established defects.

Run from this project directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

The reproduction script runs library analysis and per-fixture `mix reach.otp` JSON commands for all eight fixtures.

**Recorded evidence:** [`evidence/inv-101.json`](evidence/inv-101.json) contains both `duplicate_gen_statem_reporting` and `module_attribute_callback_mode` with `status: reproduced`. The overall `inconclusive` status is intentional because other behavior in this broader investigation remains unclassified. The evidence already includes `attr_mode.ex`; regenerate only if you change the project.
