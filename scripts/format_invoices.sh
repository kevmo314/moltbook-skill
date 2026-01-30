#!/bin/bash
# Format Lightning invoices in moltbook feed output
# Detects BOLT11 strings and decodes them using lnd-tool

LND_TOOL="${LND_TOOL:-$HOME/.openclaw/workspace/lnd-tool/target/release/lnd-tool}"

# Read all input
INPUT=$(cat)

# Check if lnd-tool exists
if [ ! -x "$LND_TOOL" ]; then
  # No lnd-tool, just pass through
  echo "$INPUT"
  exit 0
fi

# Function to decode and format a single invoice
format_invoice() {
  local invoice="$1"
  local decoded
  
  # Try to decode the invoice
  decoded=$("$LND_TOOL" decode-pay-req "$invoice" 2>/dev/null)
  
  if [ $? -ne 0 ] || [ -z "$decoded" ]; then
    # Couldn't decode, return truncated version
    echo "[Invoice: ${invoice:0:20}...${invoice: -10}]"
    return
  fi
  
  # Parse the decoded output (assuming JSON from lnd-tool)
  local amt=$(echo "$decoded" | jq -r '.num_satoshis // .num_msat // "?"' 2>/dev/null)
  local desc=$(echo "$decoded" | jq -r '.description // ""' 2>/dev/null)
  local expiry=$(echo "$decoded" | jq -r '.expiry // "?"' 2>/dev/null)
  local dest=$(echo "$decoded" | jq -r '.destination // ""' 2>/dev/null)
  
  # Format nicely
  echo ""
  echo "⚡ Lightning Invoice"
  if [ "$amt" != "?" ] && [ "$amt" != "null" ] && [ -n "$amt" ]; then
    # Format amount with commas
    local formatted_amt=$(printf "%'d" "$amt" 2>/dev/null || echo "$amt")
    echo "   Amount: ${formatted_amt} sats"
  fi
  if [ -n "$desc" ] && [ "$desc" != "null" ]; then
    echo "   Memo: \"$desc\""
  fi
  if [ "$expiry" != "?" ] && [ "$expiry" != "null" ] && [ -n "$expiry" ]; then
    echo "   Expiry: ${expiry}s"
  fi
  if [ -n "$dest" ] && [ "$dest" != "null" ]; then
    echo "   Payee: ${dest:0:12}...${dest: -8}"
  fi
  echo "   [${invoice:0:15}...] 📋"
  echo ""
}

# Find and replace BOLT11 invoices in the input
# Match lnbc, lntb, lnbcrt followed by alphanumeric (mainnet, testnet, regtest)
OUTPUT="$INPUT"

# Extract all invoices
INVOICES=$(echo "$INPUT" | grep -oE 'ln(bc|tb|bcrt)[0-9a-zA-Z]+' | sort -u)

for inv in $INVOICES; do
  # Only process if it's long enough to be a real invoice (>50 chars)
  if [ ${#inv} -gt 50 ]; then
    FORMATTED=$(format_invoice "$inv")
    # Escape special chars for sed
    ESCAPED_INV=$(echo "$inv" | sed 's/[&/\]/\\&/g')
    ESCAPED_FMT=$(echo "$FORMATTED" | sed 's/[&/\]/\\&/g' | tr '\n' '§')
    OUTPUT=$(echo "$OUTPUT" | sed "s|$ESCAPED_INV|$ESCAPED_FMT|g" | tr '§' '\n')
  fi
done

echo "$OUTPUT"
