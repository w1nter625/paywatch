#!/usr/bin/env bash
# Deploy MockUSD + PayWatchReactive + AlertBoard, then wire the board.
# Requires: foundry, PRIVATE_KEY, testnet gas on the origin chain + Lasna (lREACT).
# Default origin/destination is Ethereum Sepolia (no L2 bridge needed).
# Override with ORIGIN=base for Base Sepolia.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${PRIVATE_KEY:?Set PRIVATE_KEY to a testnet key (never a mainnet key)}"
export PATH="/home/box/.foundry/bin:${PATH:-}"

ORIGIN="${ORIGIN:-sepolia}" # sepolia | base
LASNA_RPC="${LASNA_RPC:-https://reactive-lasna.rpcscan.xyz}"
LASNA_CHAIN_ID=5318007
THRESHOLD="${THRESHOLD:-100000000}" # 100 pUSD, 6 decimals
WATCHED_WALLET="${WATCHED_WALLET:-$(cast wallet address --private-key "$PRIVATE_KEY")}"

if [[ "$ORIGIN" == "base" ]]; then
  ORIGIN_NAME="Base Sepolia"
  ORIGIN_RPC="${ORIGIN_RPC:-${BASE_RPC:-https://sepolia.base.org}}"
  ORIGIN_CHAIN_ID=84532
  CALLBACK_PROXY=0x476F44b11F5C942c58f4c8E3d0300E5710743585
else
  ORIGIN_NAME="Ethereum Sepolia"
  ORIGIN_RPC="${ORIGIN_RPC:-${SEPOLIA_RPC:-https://ethereum-sepolia.publicnode.com}}"
  ORIGIN_CHAIN_ID=11155111
  CALLBACK_PROXY=0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4
fi

echo "Deployer / default watched wallet: $WATCHED_WALLET"
echo "Origin / destination: $ORIGIN_NAME ($ORIGIN_CHAIN_ID)  rpc=$ORIGIN_RPC"
echo "Callback proxy: $CALLBACK_PROXY"
echo "Lasna rpc: $LASNA_RPC"

echo "==> MockUSD on $ORIGIN_NAME"
MOCK_OUT=$(forge create contracts/MockUSD.sol:MockUSD \
  --broadcast --rpc-url "$ORIGIN_RPC" --private-key "$PRIVATE_KEY" --chain-id "$ORIGIN_CHAIN_ID")
echo "$MOCK_OUT"
MOCK_USD=$(echo "$MOCK_OUT" | awk '/Deployed to:/ {print $3}')
echo "MockUSD: $MOCK_USD"

echo "==> PayWatchReactive on Lasna"
WATCH_OUT=$(forge create contracts/PayWatchReactive.sol:PayWatchReactive \
  --broadcast --rpc-url "$LASNA_RPC" --private-key "$PRIVATE_KEY" --chain-id "$LASNA_CHAIN_ID" \
  --value 0.05ether \
  --constructor-args "$ORIGIN_CHAIN_ID" "$MOCK_USD" "$WATCHED_WALLET" "$THRESHOLD")
echo "$WATCH_OUT"
WATCH=$(echo "$WATCH_OUT" | awk '/Deployed to:/ {print $3}')
echo "PayWatchReactive: $WATCH"

echo "==> AlertBoard on $ORIGIN_NAME"
BOARD_OUT=$(forge create contracts/AlertBoard.sol:AlertBoard \
  --broadcast --rpc-url "$ORIGIN_RPC" --private-key "$PRIVATE_KEY" --chain-id "$ORIGIN_CHAIN_ID" \
  --value 0.002ether \
  --constructor-args "$CALLBACK_PROXY" "$WATCH")
echo "$BOARD_OUT"
BOARD=$(echo "$BOARD_OUT" | awk '/Deployed to:/ {print $3}')
echo "AlertBoard: $BOARD"

echo "==> setBoard"
SETBOARD_OUT=$(cast send "$WATCH" "setBoard(address)" "$BOARD" \
  --rpc-url "$LASNA_RPC" --private-key "$PRIVATE_KEY")
echo "$SETBOARD_OUT"

# ETH sent in the AlertBoard constructor is only the contract's own balance.
# Callback fees are charged against reserves on the callback proxy; any debt
# blocks delivery (InDebt). depositTo settles debt then credits reserves.
echo "==> depositTo callback reserves on $ORIGIN_NAME"
DEPOSIT_OUT=$(cast send "$CALLBACK_PROXY" "depositTo(address)" "$BOARD" \
  --value 0.01ether --rpc-url "$ORIGIN_RPC" --private-key "$PRIVATE_KEY" || true)
echo "$DEPOSIT_OUT"
echo -n "AlertBoard debt: "; cast call "$CALLBACK_PROXY" "debt(address)(uint256)" "$BOARD" --rpc-url "$ORIGIN_RPC" || true
echo -n "AlertBoard reserves: "; cast call "$CALLBACK_PROXY" "reserves(address)(uint256)" "$BOARD" --rpc-url "$ORIGIN_RPC" || true

mkdir -p "$ROOT/broadcast"
cat > "$ROOT/broadcast/addresses.env" <<ADDRESSES
ORIGIN_NAME="$ORIGIN_NAME"
ORIGIN_CHAIN_ID=$ORIGIN_CHAIN_ID
ORIGIN_RPC=$ORIGIN_RPC
CALLBACK_PROXY=$CALLBACK_PROXY
MOCK_USD=$MOCK_USD
PAYWATCH=$WATCH
ALERT_BOARD=$BOARD
WATCHED_WALLET=$WATCHED_WALLET
THRESHOLD=$THRESHOLD
ADDRESSES
echo "Wrote broadcast/addresses.env"
