# Ash AI Tax — benchmark

Measures how many tokens an AI coding agent spends implementing the *same* feature
(a Support-ticket domain, see `SPEC.md`) in **Ash** vs **plain Phoenix + Ecto**, to a
shared green acceptance suite. Token totals differ per agent (different tokenizers /
cache accounting), so only **within-agent Ash-vs-Ecto deltas** are compared.

- `skeletons/{ash,ecto}` — clean starting apps (Ash skeleton ships the idiomatic
  `usage_rules` AGENTS.md). `reference/{ash,ecto}` — validated solutions proving the
  suite is fair/passable in both.
- `bin/run_one.sh` / `bin/run_pilot.sh` — runner + loop. `analyze.exs` — deltas.
- Pinned controls: reasoning effort = high (identical across all runs), fixed models.

## Results — N=5 (2026-05-30, opus-4-7 / gpt-5.5, effort=high)

20 runs, all green (5 per agent × framework cell).

| Agent | Ecto mean tokens | Ash mean tokens | Ash Δ | Ecto turns | Ash turns |
|-------|-----------------:|----------------:|------:|-----------:|----------:|
| Claude (opus-4-7) | 671,886 | 1,758,599 | **+162%** | 22.4 | 31.0 |
| Codex (gpt-5.5)   | 533,001 | 1,015,218 |  **+90%** | 23.2 | 32.8 |

The effect **replicates across both agents** and far exceeds the original ~25% hypothesis
(Ash ≈ 2.6× tokens on Claude, ≈ 1.9× on Codex). Deltas were stable from the n=3 pilot
(Claude +179% → +162%, Codex +85% → +90%; pilot data in `results/pilot-n3.jsonl`). Both
agents also take ~40% more turns to reach green on Ash.

Why Claude's delta is larger: its total is dominated by cache-read — the bigger Ash
context (resources + the 1,556-line usage-rules AGENTS.md) is re-read each turn, so
context size × turn count compounds.

Notes: per-run variance is high (e.g. Codex Ash 526k–1.44M), so report medians + spread
alongside means before publishing. Headline metric is tokens-processed; dollar-cost
deltas are smaller because Claude cache-read bills cheaply. Claude's flaky 400
"thinking-block" error recurs at high effort — the runner detects and retries it.
