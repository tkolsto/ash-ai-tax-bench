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

## Pilot results (2026-05-30, opus-4-7 / gpt-5.5, effort=high)

| Agent | Ecto mean tokens (n) | Ash mean tokens (n) | Ash Δ | Ecto turns | Ash turns |
|-------|---------------------:|--------------------:|------:|-----------:|----------:|
| Claude (opus-4-7) | 630,293 (3) | 1,758,599 (5) | **+179%** | 23.3 | 31.0 |
| Codex (gpt-5.5)   | 517,920 (3) |   959,491 (3) |  **+85%** | 22.7 | 32.3 |

All runs reached green. The effect **replicates across both agents** and far exceeds the
original ~25% hypothesis. Claude's larger delta is driven by cache-read tokens (the
bigger Ash context is re-read each turn, compounding with more turns). Variance is high
(Codex Ash 526k–1.26M), so N=5+ is needed before publishing a precise number.

Notes: Claude's flaky 400 "thinking block" error recurs at high effort (runner retries);
the headline metric is tokens-processed — dollar cost deltas are smaller because Claude
cache-read bills cheaply.
