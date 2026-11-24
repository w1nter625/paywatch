#!/usr/bin/env bash
# Mint pUSD and send an above-threshold transfer so the Lasna reactive
# contract can fire a callback onto AlertBoard.
# Source broadcast/addresses.env first (written by deploy.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/broadcast/addresses.env"
: "${PRIVATE_KEY:?Set PRIVATE_KEY}"
: "${MOCK_USD:?}"
: "${ALERT_BOARD:?}"
: "${PAYWATCH:?}"
export PATH="/home/box/.foundry/bin:${PATH:-}"

ORIGIN_RPC="${ORIGIN_RPC:-${SEPOLIA_RPC:-https://ethereum-sepolia.publicnode.com}}"
LASNA_RPC="${LASNA_RPC:-https://reactive-lasna.rpcscan.xyz}"
WATCHED="${WATCHED_WALLET}"
COUNTERPARTY="${COUNTERPARTY:-0x000000000000000000000000000000000000dEaD}"
AMOUNT="${AMOUNT:-250000000}" # 250 pUSD

echo "Mint 1,000 pUSD to $WATCHED"
MINT_OUT=$(cast send "$MOCK_USD" "mint(address,uint256)" "$WATCHED" 1000000000 \
  --rpc-url "$ORIGIN_RPC" --private-key "$PRIVATE_KEY")
echo "$MINT_OUT"
MINT_TX=$(echo "$MINT_OUT" | awk '/transactionHash|Transaction hash/ {print $NF; exit}')
# foundry often prints: transactionHash        0x...
if [[ -z "${MINT_TX:-}" ]]; then
  MINT_TX=$(echo "$MINT_OUT" | grep -Eo '0x[0-9a-fA-F]{64}' | head -1)
fi

echo "Transfer 250 pUSD from watched wallet to $COUNTERPARTY (outgoing, above threshold)"
XFER_OUT=$(cast send "$MOCK_USD" "transfer(address,uint256)" "$COUNTERPARTY" "$AMOUNT" \
  --rpc-url "$ORIGIN_RPC" --private-key "$PRIVATE_KEY")
echo "$XFER_OUT"
# Prefer the receipt's transactionHash line, not a hash buried in the logs JSON.
ORIGIN_TX=$(echo "$XFER_OUT" | awk '/^transactionHash/{print $2; exit}')
if [[ -z "${ORIGIN_TX:-}" ]]; then
  ORIGIN_TX=$(echo "$XFER_OUT" | grep -Eo '0x[0-9a-fA-F]{64}' | tail -1)
fi
echo "ORIGIN_TX=$ORIGIN_TX"

BEFORE=$(cast call "$ALERT_BOARD" "alertCount()(uint256)" --rpc-url "$ORIGIN_RPC")
echo "alertCount before wait: $BEFORE"

echo "Waiting for the reactive loop (poll AlertBoard up to ~3 minutes)"
ALERT_COUNT="$BEFORE"
for i in $(seq 1 36); do
  sleep 5
  ALERT_COUNT=$(cast call "$ALERT_BOARD" "alertCount()(uint256)" --rpc-url "$ORIGIN_RPC")
  echo "  t=$((i*5))s  alertCount=$ALERT_COUNT"
  if [[ "$ALERT_COUNT" != "$BEFORE" ]]; then
    break
  fi
done

echo "Latest alert (tuple):"
ALERT_TUPLE=$(cast call "$ALERT_BOARD" "alerts(uint256)((address,address,address,uint256,bool,uint256,uint256,uint256))" 1 \
  --rpc-url "$ORIGIN_RPC" || true)
echo "$ALERT_TUPLE"

# ThresholdHit on Lasna
echo "Lasna ThresholdHit logs:"
LASNA_FROM=$(cast block-number --rpc-url "$LASNA_RPC")
# look back a few hundred blocks (~few minutes at ~1s)
FROM=$((LASNA_FROM > 2000 ? LASNA_FROM - 2000 : 0))
HIT_LOGS=$(cast logs --from-block "$FROM" --to-block latest \
  --address "$PAYWATCH" \
  --rpc-url "$LASNA_RPC" \
  2>&1 || true)
echo "$HIT_LOGS"

mkdir -p "$ROOT/broadcast"
{
  echo "ORIGIN_TX=${ORIGIN_TX}"
  echo "MINT_TX=${MINT_TX}"
  echo "ALERT_COUNT=${ALERT_COUNT}"
  echo "ALERT_TUPLE=${ALERT_TUPLE}"
} >> "$ROOT/broadcast/demo-run.env"
echo "Appended broadcast/demo-run.env"
