#!/usr/bin/env bash
set -euo pipefail
# usage: run_pilot.sh [agents]   e.g. run_pilot.sh "claude"  or  run_pilot.sh "claude codex"
# Runs N runs per (agent × framework) cell into results/pilot.jsonl (fresh file).
source "$(dirname "$0")/../bench.env"
AGENTS="${1:-claude}"
: > "$BENCH_ROOT/results/pilot.jsonl"
for agent in $AGENTS; do
  for fw in ecto ash; do
    for run in $(seq 1 "$N"); do
      "$BENCH_ROOT/bin/run_one.sh" "$agent" "$fw" "$run"
    done
  done
done
echo "Pilot complete -> $BENCH_ROOT/results/pilot.jsonl"
