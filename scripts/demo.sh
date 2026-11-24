#!/usr/bin/env bash
# Mint pUSD and send a above-threshold transfer on Base Sepolia so the
# Lasna reactive contract can fire a callback onto AlertBoard.
# Source broadcast/addresses.env first (written by deploy.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/broadcast/addresses.env"
: "${PRIVATE_KEY:?Set PRIVATE_KEY}"
: "${MOCK_USD:?}"
: "${ALERT_BOARD:?}"
BASE_RPC="${BASE_RPC:-https://sepolia.base.org}"

WATCHED="${WATCHED_WALLET}"
COUNTERPARTY="${COUNTERPARTY:-0x000000000000000000000000000000000000dEaD}"
AMOUNT="${AMOUNT:-250000000}" # 250 pUSD

echo "Mint 1,000 pUSD to $WATCHED"
cast send "$MOCK_USD" "mint(address,uint256)" "$WATCHED" 1000000000 \
  --rpc-url "$BASE_RPC" --private-key "$PRIVATE_KEY"

echo "Transfer 250 pUSD from watched wallet to $COUNTERPARTY (outgoing, above threshold)"
cast send "$MOCK_USD" "transfer(address,uint256)" "$COUNTERPARTY" "$AMOUNT" \
  --rpc-url "$BASE_RPC" --private-key "$PRIVATE_KEY"

echo "Wait ~30s for the reactive loop, then read AlertBoard.alertCount"
sleep 30
echo -n "alertCount="
cast call "$ALERT_BOARD" "alertCount()(uint256)" --rpc-url "$BASE_RPC"
echo "Latest alert (tuple):"
cast call "$ALERT_BOARD" "alerts(uint256)((address,address,address,uint256,bool,uint256,uint256,uint256))" 1 \
  --rpc-url "$BASE_RPC" || true
