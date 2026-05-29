#!/usr/bin/env bash
# usage: run_one.sh <agent: claude|codex> <framework: ash|ecto> <run_n>
# Copies a clean skeleton to a temp dir, runs the agent headless with PINNED effort,
# captures token usage, retries on agent/API error, then INDEPENDENTLY verifies
# `mix test` is green. Appends one JSON record to results/pilot.jsonl.
# NOTE: no `set -e` — we handle errors explicitly so a parse hiccup never aborts a pilot.
set -uo pipefail
source "$(dirname "$0")/../bench.env"
AGENT="$1"; FW="$2"; RUN="$3"
MAX_ATTEMPTS=3
PROMPT="$(cat "$BENCH_ROOT/PROMPT.md")"

IN=0; OUT=0; CACHE=0; REASON=0; TOTAL=0; TURNS=0; COST=0
AGENT_OK=false; ERRNOTE=""; ATTEMPT=0; TRANSCRIPT=""

while [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ] && [ "$AGENT_OK" = false ]; do
  ATTEMPT=$((ATTEMPT + 1))
  STAMP="$(date +%Y%m%d-%H%M%S)-a${ATTEMPT}"
  WORK="$BENCH_ROOT/tmp/${AGENT}-${FW}-${RUN}-${STAMP}"
  mkdir -p "$WORK"; cp -R "$BENCH_ROOT/skeletons/$FW/." "$WORK/"
  cd "$WORK"
  rm -rf _build ./*.db ./*.db-* 2>/dev/null || true
  mix deps.get >/dev/null 2>&1 || true
  TRANSCRIPT="$BENCH_ROOT/results/${AGENT}-${FW}-${RUN}-${STAMP}.transcript"

  case "$AGENT" in
    claude)
      # single JSON object on stdout; keep stderr OUT of the transcript
      claude -p "$PROMPT" --output-format json --model "$CLAUDE_MODEL" \
        --effort "$EFFORT" --dangerously-skip-permissions \
        > "$TRANSCRIPT" 2>"$TRANSCRIPT.err" </dev/null || true
      # NB: jq's `//` treats false as empty, so never use `.is_error // x` here.
      IS_ERR=$(jq -r '.is_error' "$TRANSCRIPT" 2>/dev/null)
      [ -z "$IS_ERR" ] && IS_ERR=parsefail
      if [ "$IS_ERR" = "false" ]; then
        IN=$(jq -r '.usage.input_tokens // 0' "$TRANSCRIPT")
        OUT=$(jq -r '.usage.output_tokens // 0' "$TRANSCRIPT")
        CC=$(jq -r '.usage.cache_creation_input_tokens // 0' "$TRANSCRIPT")
        CR=$(jq -r '.usage.cache_read_input_tokens // 0' "$TRANSCRIPT")
        CACHE=$((CC + CR)); TURNS=$(jq -r '.num_turns // 0' "$TRANSCRIPT")
        COST=$(jq -r '.total_cost_usd // 0' "$TRANSCRIPT"); TOTAL=$((IN + CC + CR + OUT))
        AGENT_OK=true
      else
        ERRNOTE="claude is_error=$IS_ERR (attempt $ATTEMPT)"
        echo "  ! $ERRNOTE — retrying"
      fi
      ;;
    codex)
      # JSONL on stdout (plus a non-JSON banner line); keep stderr separate, close stdin
      codex exec "$PROMPT" --dangerously-bypass-approvals-and-sandbox \
        -m "$CODEX_MODEL" -c model_reasoning_effort="$EFFORT" \
        --json --skip-git-repo-check \
        > "$TRANSCRIPT" 2>"$TRANSCRIPT.err" </dev/null || true
      grep '^{' "$TRANSCRIPT" > "$TRANSCRIPT.json" 2>/dev/null || true
      NTC=$(jq -rs '[.[]|select(.type=="turn.completed")]|length' "$TRANSCRIPT.json" 2>/dev/null || echo 0)
      if [ "${NTC:-0}" -ge 1 ]; then
        IN=$(jq -rs '[.[]|select(.type=="turn.completed")|.usage.input_tokens]|add // 0' "$TRANSCRIPT.json")
        OUT=$(jq -rs '[.[]|select(.type=="turn.completed")|.usage.output_tokens]|add // 0' "$TRANSCRIPT.json")
        REASON=$(jq -rs '[.[]|select(.type=="turn.completed")|.usage.reasoning_output_tokens]|add // 0' "$TRANSCRIPT.json")
        TURNS=$(jq -rs '[.[]|select(.type=="item.completed" and .item.type=="command_execution")]|length' "$TRANSCRIPT.json" 2>/dev/null || echo 0)
        TOTAL=$((IN + OUT)); AGENT_OK=true
      else
        ERRNOTE="codex no turn.completed (attempt $ATTEMPT)"
        echo "  ! $ERRNOTE — retrying"
      fi
      ;;
    *) echo "unknown agent: $AGENT" >&2; exit 1 ;;
  esac
done

# Independently verify GREEN — never trust the agent's own claim.
if [ "$AGENT_OK" = true ] && mix test >/dev/null 2>&1; then COMPLETED=true; else COMPLETED=false; fi
[ "$AGENT_OK" = false ] && ERRNOTE="${ERRNOTE:-agent failed all $MAX_ATTEMPTS attempts}"

MODEL=$([ "$AGENT" = claude ] && echo "$CLAUDE_MODEL" || echo "$CODEX_MODEL")
jq -nc \
  --arg agent "$AGENT" --arg fw "$FW" --argjson run "$RUN" \
  --arg effort "$EFFORT" --arg model "$MODEL" --argjson attempts "$ATTEMPT" \
  --argjson in "$IN" --argjson out "$OUT" --argjson cache "$CACHE" --argjson reason "$REASON" \
  --argjson total "$TOTAL" --argjson turns "$TURNS" --argjson cost "$COST" \
  --argjson completed "$COMPLETED" --arg err "$ERRNOTE" \
  '{agent:$agent,framework:$fw,run:$run,effort:$effort,model:$model,attempts:$attempts,
    input:$in,output:$out,cache:$cache,reasoning:$reason,total:$total,
    turns:$turns,cost_usd:$cost,completed:$completed,error:$err}' \
  >> "$BENCH_ROOT/results/pilot.jsonl"

echo "[$AGENT/$FW #$RUN] total=$TOTAL (in=$IN cache=$CACHE out=$OUT reason=$REASON) turns=$TURNS green=$COMPLETED attempts=$ATTEMPT ${ERRNOTE:+ERR:$ERRNOTE}"
