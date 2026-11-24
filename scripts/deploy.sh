#!/usr/bin/env bash
# Deploy MockUSD + PayWatchReactive + AlertBoard, then wire the board.
# Requires: foundry, PRIVATE_KEY, and testnet gas on Base Sepolia + Lasna (lREACT).
# Do not run until faucets have funded the deployer.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${PRIVATE_KEY:?Set PRIVATE_KEY to a testnet key (never a mainnet key)}"
BASE_RPC="${BASE_RPC:-https://sepolia.base.org}"
LASNA_RPC="${LASNA_RPC:-https://lasna-rpc.rnk.dev/}"
BASE_CHAIN_ID=84532
LASNA_CHAIN_ID=5318007
BASE_CALLBACK_PROXY=0x476F44b11F5C942c58f4c8E3d0300E5710743585
THRESHOLD="${THRESHOLD:-100000000}" # 100 pUSD, 6 decimals
WATCHED_WALLET="${WATCHED_WALLET:-$(cast wallet address --private-key "$PRIVATE_KEY")}"

echo "Deployer / default watched wallet: $WATCHED_WALLET"

echo "==> MockUSD on Base Sepolia"
MOCK_OUT=$(forge create contracts/MockUSD.sol:MockUSD \
  --broadcast --rpc-url "$BASE_RPC" --private-key "$PRIVATE_KEY" --chain-id "$BASE_CHAIN_ID")
MOCK_USD=$(echo "$MOCK_OUT" | awk '/Deployed to:/ {print $3}')
echo "MockUSD: $MOCK_USD"

echo "==> PayWatchReactive on Lasna"
WATCH_OUT=$(forge create contracts/PayWatchReactive.sol:PayWatchReactive \
  --broadcast --rpc-url "$LASNA_RPC" --private-key "$PRIVATE_KEY" --chain-id "$LASNA_CHAIN_ID" \
  --value 0.05ether \
  --constructor-args "$BASE_CHAIN_ID" "$MOCK_USD" "$WATCHED_WALLET" "$THRESHOLD")
WATCH=$(echo "$WATCH_OUT" | awk '/Deployed to:/ {print $3}')
echo "PayWatchReactive: $WATCH"

echo "==> AlertBoard on Base Sepolia"
BOARD_OUT=$(forge create contracts/AlertBoard.sol:AlertBoard \
  --broadcast --rpc-url "$BASE_RPC" --private-key "$PRIVATE_KEY" --chain-id "$BASE_CHAIN_ID" \
  --value 0.002ether \
  --constructor-args "$BASE_CALLBACK_PROXY" "$WATCH")
BOARD=$(echo "$BOARD_OUT" | awk '/Deployed to:/ {print $3}')
echo "AlertBoard: $BOARD"

echo "==> setBoard"
cast send "$WATCH" "setBoard(address)" "$BOARD" \
  --rpc-url "$LASNA_RPC" --private-key "$PRIVATE_KEY"

mkdir -p "$ROOT/broadcast"
cat > "$ROOT/broadcast/addresses.env" <<ADDRESSES
MOCK_USD=$MOCK_USD
PAYWATCH=$WATCH
ALERT_BOARD=$BOARD
WATCHED_WALLET=$WATCHED_WALLET
THRESHOLD=$THRESHOLD
ADDRESSES
echo "Wrote broadcast/addresses.env"
