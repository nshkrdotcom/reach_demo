# INV-100 evidence

[`inv-100.json`](inv-100.json) records Reach 2.8.4 behavior (Elixir 1.20.5, OTP 29), including the two-controller `fixtures/phoenix/extra.ex` case and the Ecto connected/unrelated cast controls. In `comparisons`, the Phoenix cross-controller fallback and Ecto same-function candidate-flow findings both have `status: reproduced`. These support proposed issues 107 and 108.

The overall `inconclusive` status applies to the broader framework investigation, including separate Ash observations; it does **not** mean those two specific findings failed. The report contains fixture hashes and Hex provenance. Regenerate it only after making changes to the relevant inputs or implementation.
