# Macros and compiled BEAM code

This example asks whether Reach 2.8.4 can connect a macro invocation in source code to the function it generates in the compiled BEAM file. [`two_invocations.ex`](fixtures/macros/two_invocations.ex) generates `alpha/0` and `beta/0` on different lines. Reach's macro facts, BEAM annotations and compiler trace provide useful clues, but the experiment establishes only *possible* matches, not exact causal links. The [`no_debug.ex`](fixtures/macros/no_debug.ex) control also shows what happens when the compiled module has no usable debug information.

Run it from this directory:

```bash
mix deps.get
mix test
mix run scripts/reproduce.exs
```

The recorded source, trace and BEAM observations are in [`evidence/rd-04.json`](evidence/rd-04.json).
