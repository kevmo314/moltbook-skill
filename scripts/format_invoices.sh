#!/bin/bash
# Format Lightning invoices in moltbook feed output
# Detects BOLT11 strings and decodes them - no external dependencies required

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DECODER="$SCRIPT_DIR/decode_bolt11.py"

# Read all input
INPUT=$(cat)

# Function to decode and format a single invoice
format_invoice() {
  local invoice="$1"
  
  # Try Python decoder (included, no deps)
  if command -v python3 &>/dev/null && [ -f "$DECODER" ]; then
    python3 "$DECODER" "$invoice" 2>/dev/null
    if [ $? -eq 0 ]; then
      return
    fi
  fi
  
  # Fallback: basic HRP parsing with pure bash
  local hrp="${invoice%%1*}"
  local network=""
  local amount=""
  
  case "$hrp" in
    lnbc*) network="mainnet" ;;
    lntb*) network="testnet" ;;
    lnbcrt*) network="regtest" ;;
    *) 
      echo "[Invoice: ${invoice:0:20}...${invoice: -10}]"
      return
      ;;
  esac
  
  # Try to extract amount from HRP (e.g., lnbc100u -> 100 micro-btc)
  local amt_part="${hrp#ln??}"
  amt_part="${amt_part#?}"  # handle lnbcrt
  if [[ "$amt_part" =~ ^([0-9]+)([munp])?$ ]]; then
    local num="${BASH_REMATCH[1]}"
    local mult="${BASH_REMATCH[2]}"
    case "$mult" in
      m) amount=$((num * 100000)) ;;
      u) amount=$((num * 100)) ;;
      n) amount=$((num / 10)) ;;
      p) amount=$((num / 10000)) ;;
      *) amount=$((num * 100000000)) ;;
    esac
  fi
  
  echo ""
  echo "⚡ Lightning Invoice ($network)"
  if [ -n "$amount" ] && [ "$amount" -gt 0 ]; then
    printf "   Amount: %'d sats\n" "$amount"
  fi
  echo "   [${invoice:0:20}...${invoice: -10}] 📋"
  echo ""
}

# Find and replace BOLT11 invoices in the input
OUTPUT="$INPUT"

# Extract all invoices (match ln followed by bc/tb/bcrt and alphanumeric)
INVOICES=$(echo "$INPUT" | grep -oE 'ln(bc|tb|bcrt)[0-9a-zA-Z]+' | sort -u)

for inv in $INVOICES; do
  # Only process if it's long enough to be a real invoice (>50 chars)
  if [ ${#inv} -gt 50 ]; then
    FORMATTED=$(format_invoice "$inv")
    # Escape special chars for sed
    ESCAPED_INV=$(printf '%s\n' "$inv" | sed 's/[[\.*^$()+?{|]/\\&/g')
    ESCAPED_FMT=$(printf '%s\n' "$FORMATTED" | sed 's/[&/\]/\\&/g' | tr '\n' '§')
    OUTPUT=$(echo "$OUTPUT" | sed "s|$ESCAPED_INV|$ESCAPED_FMT|g" | tr '§' '\n')
  fi
done

echo "$OUTPUT"
