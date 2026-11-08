# GenServer messages and replies

This example tests which calls and message payloads Reach 2.8.4 connects to GenServer handlers. In [`same_file.ex`](fixtures/same_file.ex), a call addressed to Server A also receives three payload links into Server B and a reply link from Server B. Those generic links disappear when the modules are analyzed from [separate files](fixtures/separate/). The [`wrong_arity.ex`](fixtures/wrong_arity.ex) example also links a `handle_call/1` decoy as if it were a callback; the [guardless](fixtures/guardless.ex) and [guarded](fixtures/guarded.ex) examples expose a body-local binding difference. These are graph edges, not messages that were actually delivered.

Run it from this directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

The recorded edges and their source/target owners are in [`evidence/rd-02.json`](evidence/rd-02.json).
