# RD-06 — Per-file parse/build diagnostics missing from project results

**Upstream draft 106; original proposal RCH-03.** Standalone Mix project.
It does not modify RD-01–04 or any previously opened GitHub issue.

`fixtures/valid.ex` parses; `fixtures/invalid.ex` deliberately does not.
The primary comparison is a normal full-SDG `Reach.Project.from_sources/2`
build of the valid file versus valid + invalid. A secondary `source_only`
comparison checks the same behavior. The report records actual project
fields, node counts, function names and whether an API reports the specific
failed path, without assuming hypothetical diagnostic field names.

`ExUnit.CaptureLog` / `ExUnit.CaptureIO` are started explicitly so the
standalone `mix run` script can capture output just like `mix test`. Logged
errors are not equivalent to a structured per-file report in the returned
project. An **isolated side probe** passes a non-Elixir `.txt` file explicitly;
Reach 2.8.4's unknown-extension language fallback attempts Elixir parsing.
If that side probe raises, it is recorded separately, not allowed to destroy
the main result. This project does **not** use Gleam availability as evidence
of a silent skip: missing `glance` can raise instead.

Run from this project directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

Inspect `evidence/rd-06.json`. Failures are written to
`evidence/rd-06.failure.json`. The upstream-fix test is excluded by default;
use `mix test --include expected_fix` only against a version offering a
structured parse diagnostics API. No runtime evidence is bundled.
