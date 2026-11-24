# PayWatch

A personal large-transfer watchdog for the [Reactive Omni Buildathon](https://dorahacks.io/hackathon/reactive-omni-buildathon), **Set It and Forget It** track.

If a watched wallet sends or receives an ERC-20 transfer at or above a threshold, a reactive contract on Lasna notices the `Transfer` log and requests a callback onto an `AlertBoard` on Base Sepolia. No bot to keep online. You can leave it running.

**Demo video (75 seconds, English narration + captions):** [jsDelivr](https://cdn.jsdelivr.net/gh/w1nter625/paywatch@gh-pages/demo.mp4)

## Why this is useful

People already screenshot “did this payment land?” or run a watcher script that dies when the laptop sleeps. PayWatch is the same habit, on-chain: a cap you actually want to keep. In production you point it at USDC (or another token) on Base. The demo deploys a small `MockUSD` (pUSD, 6 decimals) so the full loop can be shown on testnets without depending on a faucet-issued stablecoin.

## The loop

```
Base Sepolia                         Lasna                         Base Sepolia
MockUSD.Transfer  ─────────────────► PayWatchReactive.react()
  (watched wallet, amount ≥ cap)           │
                                           └── requestCallbackV_1_0 ──► AlertBoard.recordAlert
                                                                         (authenticated via proxy)
```

- Origin and destination: Base Sepolia (chain ID 84532), callback proxy `0x476F44b11F5C942c58f4c8E3d0300E5710743585`.
- Reactive chain: Lasna (chain ID 5318007), system contract `0x8888…8888`.
- Cooldown is in **seconds** (`block.timestamp`), not block counts, as required for fast testnets.
- `AlertBoard` accepts calls only from the callback proxy, and only when the injected sender is the authorized reactive contract.

## Contracts

| Contract | Chain | Role |
|---|---|---|
| `MockUSD` | Base Sepolia | Demo ERC-20 that emits standard `Transfer` logs |
| `PayWatchReactive` | Lasna | Subscribes, filters, requests the callback |
| `AlertBoard` | Base Sepolia | Records the alert |

Deployment order follows the official docs: reactive contract first, then the board (it needs the reactive address), then `setBoard` on the reactive contract, then fund both.

Live testnet addresses and the origin → reactive → callback transaction hashes will be listed in `demo-txs.md` after the faucet step below.

## Tests

```bash
forge test -vv
```

The suite etches a mock system contract at `0x8888…8888` and covers: subscribe on construct, incoming and outgoing hits, below-threshold / wrong token / unwatched wallet, cooldown, `onlySystem` / `onlyOwner`, no callback until the board is set, and AlertBoard authentication. **14/14 passing.**

## Deploy (testnet)

Needs Base Sepolia ETH and Lasna `lREACT`. Official docs: [Reactive Mainnet / Lasna Testnet](https://dev.reactive.network/reactive-mainnet). There is no official login-free drip of lREACT by itself. You first obtain Sepolia or Base Sepolia test ETH from a public faucet, then mint lREACT by sending that test ETH to a faucet contract (plain value transfer or `request(address)`):

- Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`
- Base Sepolia: `0x2afaFD298b23b62760711756088F75B7409f5967`

Exchange rate: **1 ETH → 100 lREACT**. Do not send more than 5 ETH per transaction (max 500 lREACT; amounts above 5 ETH are lost). Example: `0.01` ETH → `1` lREACT, enough for the 0.05 lREACT constructor funding plus gas.

Do not send mainnet funds. Do not buy ETH or REACT. Put a **testnet** key in `PRIVATE_KEY` (see `.env.example`) and run:

```bash
export PRIVATE_KEY=0x...   # testnet only; prefer .secrets/private_key.txt
./scripts/request-lreact.sh base 0.01ether   # once you have Base Sepolia ETH
./scripts/deploy.sh
./scripts/demo.sh          # mints pUSD, sends 250 (above the 100 cap), then reads alertCount
```

If `forge`/`cast` get HTTP 403 from `https://lasna-rpc.rnk.dev/`, start `python3 scripts/lasna-proxy.py` and set `LASNA_RPC=http://127.0.0.1:8549`.

Addresses are written to `broadcast/addresses.env` (gitignored). Record the origin transfer hash and the AlertBoard callback hash in `demo-txs.md` for the DoraHacks submission.

## License

MIT. See [LICENSE](LICENSE).
