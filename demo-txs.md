# PayWatch live testnet transactions

Recorded 2026-11-24, times in **SGT (UTC+8)**. Origin and destination are **Ethereum Sepolia** (chain 11155111), which is a supported Reactive testnet pair. The reactive contract is on **Lasna** (5318007).

The Set It and Forget It track allows any chain Reactive supports. Ethereum Sepolia was used so the 0.055 Sepolia ETH faucet drop did not have to be bridged to Base Sepolia.

## Contracts

| Contract | Chain | Address | Deploy tx |
|---|---|---|---|
| MockUSD | Ethereum Sepolia | [`0x8BE488697F24bC49ffBDE035e1F3e6A6fc9227D8`](https://sepolia.etherscan.io/address/0x8BE488697F24bC49ffBDE035e1F3e6A6fc9227D8) | [`0x3e11aa1d…55dce1d`](https://sepolia.etherscan.io/tx/0x3e11aa1dc64afe77ddbce371318130578f65a8a3ade85ba050fcb06b355dce1d) |
| PayWatchReactive | Lasna | [`0x4A87e098771e3F4713c80c7dcd2AC740C0fe9184`](https://lasna.reactscan.net/address/0x4A87e098771e3F4713c80c7dcd2AC740C0fe9184) | [`0x0cf38995…94b4ab7d`](https://lasna.reactscan.net/tx/0x0cf389959c4eabf6147a0d3e707cbab73ae3a7613b72d5821f64433294b4ab7d) |
| AlertBoard | Ethereum Sepolia | [`0x4644c437ff8cb069A68E08FdE8b2998D1A10A4c8`](https://sepolia.etherscan.io/address/0x4644c437ff8cb069A68E08FdE8b2998D1A10A4c8) | [`0xc8462587…9cef88d`](https://sepolia.etherscan.io/tx/0xc8462587c32d8d1e90a8048a740b169190abb157c35957c2f1de56c1b9cef88d) |

- Deployer / watched wallet: `0xe9229A666D0B9f213429c407Ff730A9287FCA96E`
- Sepolia callback proxy: `0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4`
- Threshold: 100 pUSD (6 decimals). Cooldown: 60 seconds.
- `setBoard`: [`0x0beefdd3abbcd0da84a4fa183e0a7d0fe05a19b92ad08ac4da31195ba5084993`](https://lasna.reactscan.net/tx/0x0beefdd3abbcd0da84a4fa183e0a7d0fe05a19b92ad08ac4da31195ba5084993)

Full hashes:

- MockUSD deploy: `0x3e11aa1dc64afe77ddbce371318130578f65a8a3ade85ba050fcb06b355dce1d`
- PayWatchReactive deploy: `0x0cf389959c4eabf6147a0d3e707cbab73ae3a7613b72d5821f64433294b4ab7d`
- AlertBoard deploy: `0xc8462587c32d8d1e90a8048a740b169190abb157c35957c2f1de56c1b9cef88d`

## Official lREACT

- Sent 0.01 Sepolia ETH via `request(address)` to `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`
- Tx: [`0x23a823cd1e3df94dfc83cc11af1a108e38e3412aafb30851dd6272f11279557c`](https://sepolia.etherscan.io/tx/0x23a823cd1e3df94dfc83cc11af1a108e38e3412aafb30851dd6272f11279557c)
- Received **1.05 lREACT** on Lasna (rate 1 ETH → 100 lREACT).

## The loop (primary demo)

Outgoing 250 pUSD transfer from the watched wallet to `0x…dEaD`, after callback reserves were funded.

| Leg | Chain | What | Tx |
|---|---|---|---|
| Origin | Ethereum Sepolia | `MockUSD.Transfer` of 250 pUSD (above the 100 cap), watched wallet → `0x…dEaD` | [`0xc75466d83608d3b1da65d19a9784c14e991e71d9ccffc416c04413a13212786f`](https://sepolia.etherscan.io/tx/0xc75466d83608d3b1da65d19a9784c14e991e71d9ccffc416c04413a13212786f) |
| Reactive | Lasna | `PayWatchReactive.ThresholdHit` + system `CallbackRequest` to AlertBoard | [`0x6e069f8117b128096ccb50bd7e06173f4282fc6f714386eefc1297aab9f868f0`](https://lasna.reactscan.net/tx/0x6e069f8117b128096ccb50bd7e06173f4282fc6f714386eefc1297aab9f868f0) |
| Callback | Ethereum Sepolia | `AlertBoard.AlertRecorded` via the official callback proxy | **pending** as of 2026-11-24 23:02 SGT |

`fireCount` on Lasna is **2**. `AlertBoard.alertCount` on Sepolia is still **0**. `getCallbacks` for the reactive tx is still `[]`, and Etherscan shows no transaction on AlertBoard besides its deploy. The Reactive signer has not yet posted the destination transaction.

### Why the first callback could not land, and what was fixed

ETH sent to AlertBoard in the constructor sits on the contract as a plain balance. Callback fees are billed from **reserves** on the callback proxy. Any **debt > 0** blocks delivery (`InDebt`). After the first react, the proxy showed a small debt (`17148393` wei) and zero reserves.

`depositTo(AlertBoard)` on the Sepolia callback proxy cleared the debt and credited ~0.01 ETH of reserves:

- [`0x6b3f2fbeed12362841ed1c6ce6326487411998e0bc00a24cfe8f651b5ccd24da`](https://sepolia.etherscan.io/tx/0x6b3f2fbeed12362841ed1c6ce6326487411998e0bc00a24cfe8f651b5ccd24da)
- After this: `debt = 0`, `reserves ≈ 0.01 ETH`.

The primary demo transfer above was sent *after* that deposit. Lasna still reacted (`ThresholdHit` + `CallbackRequest`, `fireCount = 2`). Destination delivery was still outstanding more than eight minutes later. Other public write-ups of this buildathon saw Sepolia callbacks land in about 10 seconds, so this looks like a signer/queue delay rather than a lack of testnet ETH. Deployer still holds ~0.033 Sepolia ETH and ~0.92 lREACT.

`scripts/deploy.sh` now calls `depositTo` after `setBoard`.

## Earlier origin event (same contracts)

The first `ThresholdHit` was triggered by minting 1,000 pUSD to the watched wallet (incoming, also above the cap), at 22:44:36 SGT, *before* reserves were funded:

| Leg | Tx |
|---|---|
| Origin mint `Transfer` | [`0x69edc6c688bdfc270a621f48f3010e3a1a8231ec7d5b31d3e01a5286b0b63984`](https://sepolia.etherscan.io/tx/0x69edc6c688bdfc270a621f48f3010e3a1a8231ec7d5b31d3e01a5286b0b63984) |
| Lasna `ThresholdHit` + `CallbackRequest` | [`0x24307e71da4ae2ce6f5f3d21fa154772a801ecb7d696b5e4d0969bc0cebfc7b6`](https://lasna.reactscan.net/tx/0x24307e71da4ae2ce6f5f3d21fa154772a801ecb7d696b5e4d0969bc0cebfc7b6) |
