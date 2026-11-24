#!/usr/bin/env bash
# Mint Lasna lREACT via the official Reactive faucet contracts.
# Official docs: https://dev.reactive.network/reactive-mainnet
# This does NOT buy tokens. It spends testnet ETH you already received from a faucet.
#
# Usage:
#   export PRIVATE_KEY from .secrets/private_key.txt
#   ./scripts/request-lreact.sh base 0.01ether     # Base Sepolia (preferred)
#   ./scripts/request-lreact.sh sepolia 0.01ether  # Ethereum Sepolia
set -euo pipefail
: "${PRIVATE_KEY:?Set PRIVATE_KEY to the testnet key (never a mainnet key)}"
CHAIN="${1:-base}"
VALUE="${2:-0.01ether}"
export PATH="/home/box/.foundry/bin:${PATH}"
ADDR="$(cast wallet address --private-key "$PRIVATE_KEY")"

if [[ "$CHAIN" == "base" ]]; then
  FAUCET=0x2afaFD298b23b62760711756088F75B7409f5967
  RPC="${BASE_RPC:-https://sepolia.base.org}"
  NAME="Base Sepolia"
else
  FAUCET=0x9b9BB25f1A81078C544C829c5EB7822d747Cf434
  RPC="${SEPOLIA_RPC:-https://ethereum-sepolia.publicnode.com}"
  NAME="Ethereum Sepolia"
fi

echo "Wallet:  $ADDR"
echo "Network: $NAME"
echo "Faucet:  $FAUCET"
echo "Amount:  $VALUE  (rate 1 ETH → 100 lREACT; do not send more than 5 ETH)"
echo "Balance: $(cast balance "$ADDR" --rpc-url "$RPC" --ether) ETH"
# Official docs support both a plain value transfer and request(address).
# request(address) lets you credit a specific Lasna recipient; we credit ourselves.
cast send "$FAUCET" "request(address)" "$ADDR" \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --value "$VALUE"
echo "Request sent. lREACT should arrive on Lasna (chain 5318007) shortly."
