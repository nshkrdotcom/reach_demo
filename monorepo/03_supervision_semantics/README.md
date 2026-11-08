# Supervisor detection

This example checks how Reach 2.8.4 recognizes supervisors and their children. It finds the conventional supervisor in [`standard.ex`](fixtures/standard.ex), but reports no children even though two workers are configured. It misses the direct [`Supervisor.start_link`](fixtures/direct.ex) example, while incorrectly identifying a plain GenServer that calls an unrelated `Foo.init/1` in [`false_positive.ex`](fixtures/false_positive.ex). The direct example was not discovered, so a direct-versus-standard *child extraction* comparison remains unresolved. The fixtures also cover restart strategies, child policies and DynamicSupervisor.

Run it from this directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

The recorded supervisor output is in [`evidence/rd-03.json`](evidence/rd-03.json).
