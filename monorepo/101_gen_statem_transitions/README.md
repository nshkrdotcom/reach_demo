# INV-101 — `gen_statem` transition investigation (RCH-10)

**Investigation only; not GitHub issue draft 101.** The two numbering
systems happen to overlap but concern different subjects.

Seven inert, source-parsed fixtures cover `:state_functions`,
`:handle_event_function`, `[:handle_event_function, :state_enter]`,
`:keep_state`/`:repeat_state`, postponed events and timers, guards, and a
truly dynamic callback mode without either mode literal.

The script records BOTH `Reach.OTP.GenStatem.analyze/1` results and
**separate user-facing CLI commands for each fixture**:

```text
mix reach.otp fixtures/state_functions_basic.ex --format json
mix reach.otp fixtures/handle_event_basic.ex --format json
# ...and the five remaining fixture paths
```

It captures the CLI exit status, whether the output is valid JSON, and a
bounded excerpt. An unsuccessful CLI call is an observation; it does not
silently become a claim that a state-machine analysis bug was reproduced.
The compiled `CliSmoke` module from v2 has been removed, because it did not
test the other six cases.

Reach 2.8.4's source suggests state-functions transitions have `nil`
triggers while handle-event transitions may have explicit triggers; the
current extractor also does not add `keep_state`/`repeat_state` self-loops.
These can be intentional abstractions. `:state_enter`, postponement and guard
feasibility require separate interpretation rather than a blanket failure
claim.

Run from this directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

Read the per-fixture library and CLI rows in `evidence/inv-101.json`.
No runtime results are pre-populated; classification remains `inconclusive`
until the observed cases are reviewed.
