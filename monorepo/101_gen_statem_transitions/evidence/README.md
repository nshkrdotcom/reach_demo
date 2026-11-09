# INV-101 evidence

[`inv-101.json`](inv-101.json) records Reach 2.8.4 results (Elixir 1.20.5, OTP 29) for eight source fixtures, including `fixtures/attr_mode.ex`, and their corresponding CLI analyses. The `comparisons` section contains two verified findings: `duplicate_gen_statem_reporting` and `module_attribute_callback_mode`, each with `status: reproduced`; these support proposed issues 109 and 110.

The overall `inconclusive` status covers other, unclassified `gen_statem` behavior and does not negate those reproduced findings. The report includes input hashes and Hex provenance. Re-run `mix run scripts/reproduce.exs` only after changing the fixtures or investigation.
