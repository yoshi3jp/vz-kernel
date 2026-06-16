#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <.config> <required-symbols-file>" >&2
  exit 2
fi

CONFIG_FILE="$1"
REQUIRED="$2"
FAILED=0

while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  symbol="${line%%=*}"
  expected="${line#*=}"
  actual="$(grep -E "^${symbol}=" "$CONFIG_FILE" || true)"
  if [[ "$actual" != "$symbol=$expected" ]]; then
    echo "missing or wrong: expected $symbol=$expected, got '${actual:-unset}'" >&2
    FAILED=1
  fi
done < "$REQUIRED"

if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi
