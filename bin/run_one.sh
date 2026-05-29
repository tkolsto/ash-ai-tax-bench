#!/usr/bin/env bash
set -euo pipefail
# usage: run_one.sh <agent: claude|codex> <framework: ash|ecto> <run_n>
# Copies a clean skeleton to a temp dir, runs the agent headless with PINNED effort,
# captures token usage, then INDEPENDENTLY verifies `mix test` is green. Appends one
# JSON record to results/pilot.jsonl. Token totals differ per agent (see comments) —
# only WITHIN-agent Ash-vs-Ecto deltas are comparable.
source "$(dirname "$0")/../bench.env"
AGENT="$1"; FW="$2"; RUN="$3"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="$BENCH_ROOT/tmp/${AGENT}-${FW}-${RUN}-${STAMP}"
mkdir -p "$WORK"
cp -R "$BENCH_ROOT/skeletons/$FW/." "$WORK/"
cd "$WORK"
rm -rf _build ./*.db ./*.db-* 2>/dev/null || true   # clean build per run; keep deps source
mix deps.get >/dev/null 2>&1 || true

PROMPT="$(cat "$BENCH_ROOT/PROMPT.md")"
TRANSCRIPT="$BENCH_ROOT/results/${AGENT}-${FW}-${RUN}-${STAMP}.transcript"
CACHE=0; REASON=0; COST=0; TURNS=0

case "$AGENT" in
  claude)
    # .usage.input_tokens is ONLY fresh input; real input adds the two cache buckets.
    claude -p "$PROMPT" --output-format json --model "$CLAUDE_MODEL" \
      --effort "$EFFORT" --dangerously-skip-permissions > "$TRANSCRIPT" 2>&1 || true
    IN=$(jq -r '.usage.input_tokens // 0' "$TRANSCRIPT")
    OUT=$(jq -r '.usage.output_tokens // 0' "$TRANSCRIPT")
    CC=$(jq -r '.usage.cache_creation_input_tokens // 0' "$TRANSCRIPT")
    CR=$(jq -r '.usage.cache_read_input_tokens // 0' "$TRANSCRIPT")
    CACHE=$((CC + CR)); TURNS=$(jq -r '.num_turns // 0' "$TRANSCRIPT")
    COST=$(jq -r '.total_cost_usd // 0' "$TRANSCRIPT")
    TOTAL=$((IN + CC + CR + OUT))
    ;;
  codex)
    # usage lives in turn.completed events; input_tokens already includes cached.
    codex exec "$PROMPT" --dangerously-bypass-approvals-and-sandbox \
      -m "$CODEX_MODEL" -c model_reasoning_effort="$EFFORT" \
      --json --skip-git-repo-check > "$TRANSCRIPT" 2>&1 || true
    IN=$(jq -rs '[.[]|select(.type=="turn.completed")|.usage.input_tokens]|add // 0' "$TRANSCRIPT")
    OUT=$(jq -rs '[.[]|select(.type=="turn.completed")|.usage.output_tokens]|add // 0' "$TRANSCRIPT")
    REASON=$(jq -rs '[.[]|select(.type=="turn.completed")|.usage.reasoning_output_tokens]|add // 0' "$TRANSCRIPT")
    TURNS=$(jq -rs '[.[]|select(.type=="turn.completed")]|length' "$TRANSCRIPT")
    TOTAL=$((IN + OUT))
    ;;
  *) echo "unknown agent: $AGENT" >&2; exit 1 ;;
esac

# Independently verify GREEN — never trust the agent's own claim.
if mix test >/dev/null 2>&1; then COMPLETED=true; else COMPLETED=false; fi

MODEL=$([ "$AGENT" = claude ] && echo "$CLAUDE_MODEL" || echo "$CODEX_MODEL")
jq -nc \
  --arg agent "$AGENT" --arg fw "$FW" --argjson run "$RUN" \
  --arg effort "$EFFORT" --arg model "$MODEL" \
  --argjson in "$IN" --argjson out "$OUT" --argjson cache "$CACHE" --argjson reason "$REASON" \
  --argjson total "$TOTAL" --argjson turns "$TURNS" --argjson cost "$COST" --argjson completed "$COMPLETED" \
  '{agent:$agent,framework:$fw,run:$run,effort:$effort,model:$model,
    input:$in,output:$out,cache:$cache,reasoning:$reason,total:$total,
    turns:$turns,cost_usd:$cost,completed:$completed}' \
  >> "$BENCH_ROOT/results/pilot.jsonl"

echo "[$AGENT/$FW #$RUN] total=$TOTAL (in=$IN cache=$CACHE out=$OUT reason=$REASON) turns=$TURNS green=$COMPLETED"
