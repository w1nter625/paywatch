# PayWatch live testnet transactions

Recorded **2026-11-26**, times in **SGT (UTC+8)**. Origin and destination are **Ethereum Sepolia** (chain 11155111). The reactive contract is on **Lasna** (5318007).

The Set It and Forget It track allows any chain Reactive supports. Ethereum Sepolia was used so the 0.055 Sepolia ETH faucet drop did not have to be bridged to Base Sepolia.

This is the **second deploy**. The first (2026-11-24) requested callbacks correctly, but `recordAlert` ran out of gas on the destination (see below). These addresses and hashes supersede that deploy.

## Contracts

| Contract | Chain | Address | Deploy tx |
|---|---|---|---|
| MockUSD (reused) | Ethereum Sepolia | [`0x8BE488697F24bC49ffBDE035e1F3e6A6fc9227D8`](https://sepolia.etherscan.io/address/0x8BE488697F24bC49ffBDE035e1F3e6A6fc9227D8) | [`0x3e11aa1d…55dce1d`](https://sepolia.etherscan.io/tx/0x3e11aa1dc64afe77ddbce371318130578f65a8a3ade85ba050fcb06b355dce1d) |
| PayWatchReactive | Lasna | [`0x4644c437ff8cb069A68E08FdE8b2998D1A10A4c8`](https://lasna.reactscan.net/address/0x4644c437ff8cb069A68E08FdE8b2998D1A10A4c8) | [`0x94b1c9be…32c3b0`](https://lasna.reactscan.net/tx/0x94b1c9becec7cbf541f2c52ecf26bee8b9cd0ab142e3d1107d9321b7f632c3b0) (10:08:34 SGT) |
| AlertBoard | Ethereum Sepolia | [`0x3638305409342f605c2D799DB3b5201d3648Fb47`](https://sepolia.etherscan.io/address/0x3638305409342f605c2D799DB3b5201d3648Fb47) | [`0x252881e0…8eb03a`](https://sepolia.etherscan.io/tx/0x252881e08a7a011f1519e338557b67a51b7da749727a5109cebea10f1b8eb03a) (10:08:48 SGT) |

- Deployer / watched wallet: `0xe9229A666D0B9f213429c407Ff730A9287FCA96E`
- Sepolia callback proxy: `0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4`
- Threshold: 100 pUSD (6 decimals). Cooldown: 60 seconds.
- `CALLBACK_GAS_LIMIT`: **2,500,000** (raised from 1,000,000 after the first deploy ran out of gas).
- `setBoard`: [`0x3ffeaf18faea1149cb8e1c3d6716dd30487b028e9c9f1fb35ced9e5305754e4c`](https://lasna.reactscan.net/tx/0x3ffeaf18faea1149cb8e1c3d6716dd30487b028e9c9f1fb35ced9e5305754e4c) (10:08:51 SGT)
- `depositTo` reserves (0.01 ETH, `debt = 0`, `reserves = 0.01 ETH`): [`0xe87dac75eea1c5f6b0029d89938136da353071451a8593ce85e0bb7f93ca8c1f`](https://sepolia.etherscan.io/tx/0xe87dac75eea1c5f6b0029d89938136da353071451a8593ce85e0bb7f93ca8c1f) (10:09:00 SGT)

Full deploy hashes:

- MockUSD deploy: `0x3e11aa1dc64afe77ddbce371318130578f65a8a3ade85ba050fcb06b355dce1d`
- PayWatchReactive deploy: `0x94b1c9becec7cbf541f2c52ecf26bee8b9cd0ab142e3d1107d9321b7f632c3b0`
- AlertBoard deploy: `0x252881e08a7a011f1519e338557b67a51b7da749727a5109cebea10f1b8eb03a`

Note: the new Lasna PayWatchReactive address is coincidentally the same 20 bytes as the *first* Sepolia AlertBoard (`0x4644…A4c8`). They live on different chains. Do not confuse them with the superseded first-deploy AlertBoard.

## Official lREACT

- Sent 0.01 Sepolia ETH via `request(address)` to `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`
- Tx: [`0x23a823cd1e3df94dfc83cc11af1a108e38e3412aafb30851dd6272f11279557c`](https://sepolia.etherscan.io/tx/0x23a823cd1e3df94dfc83cc11af1a108e38e3412aafb30851dd6272f11279557c)
- Received **1.05 lREACT** on Lasna (rate 1 ETH → 100 lREACT). The second PayWatch constructor was funded from the remaining wallet balance (~0.92 lREACT).

## The loop (complete)

Outgoing 250 pUSD transfer from the watched wallet to `0x…dEaD`, after callback reserves were funded and after `CALLBACK_GAS_LIMIT` was raised to 2,500,000.

| Leg | Chain | What | Time (SGT) | Tx |
|---|---|---|---|---|
| Origin | Ethereum Sepolia | `MockUSD.Transfer` of 250 pUSD (above the 100 cap), watched wallet → `0x…dEaD` | 2026-11-26 10:09:48 | [`0x1e84dc2c55582d201af4727237ad0c84ebc8cef4f39ed502ecd14391bcbb73ff`](https://sepolia.etherscan.io/tx/0x1e84dc2c55582d201af4727237ad0c84ebc8cef4f39ed502ecd14391bcbb73ff) |
| Reactive | Lasna | `PayWatchReactive.ThresholdHit` + system `CallbackRequest` to AlertBoard | 2026-11-26 10:09:47 | [`0xd9e9ae6cf21264224b7929bd00fc162e8231a8b548d0fcd9a7c366faf0deaa04`](https://lasna.reactscan.net/tx/0xd9e9ae6cf21264224b7929bd00fc162e8231a8b548d0fcd9a7c366faf0deaa04) |
| Callback | Ethereum Sepolia | `AlertBoard.AlertRecorded` (id 1) via the official callback proxy | 2026-11-26 10:10:00 | [`0x0dd4f36715848625b500a1a591e31ecf1d8d927c6264939c54e73cdbe1651ef1`](https://sepolia.etherscan.io/tx/0x0dd4f36715848625b500a1a591e31ecf1d8d927c6264939c54e73cdbe1651ef1) |

The Lasna clock is about one second ahead of Sepolia; the destination transaction landed in the next Sepolia block, **12 seconds** after the origin transfer. `fireCount = 1`, `alertCount = 1`, proxy `debt = 0`. `alerts(1)` stores the watched wallet, `0x…dEaD`, MockUSD, 250 pUSD, `incoming = false`, chain 11155111, and the origin tx hash above.

Callback transaction gas used: **954,481**. That is more than the ~745k the proxy forwards from a 1,000,000 `gasLimit`, which is why the first deploy failed.

## Why the first deploy's callbacks failed (2026-11-24)

The first contracts were:

- PayWatchReactive (Lasna): `0x4A87e098771e3F4713c80c7dcd2AC740C0fe9184`
- AlertBoard (Ethereum Sepolia): `0x4644c437ff8cb069A68E08FdE8b2998D1A10A4c8`

Payload format, official proxy, chain ID, and authorization (injected sender = the reactive contract, RvmId `0x0` on Omni) were all correct. Reserves were funded after the first request. The official signer **did** post destination transactions, about one Sepolia block later — they were easy to miss because they go to the **callback proxy**, not to AlertBoard as the top-level `to`:

- First attempt (before reserves; went into debt): [`0x09c086f266f315097e2a43a1d240037597320ebcfce43e37766b8b1b557cdd18`](https://sepolia.etherscan.io/tx/0x09c086f266f315097e2a43a1d240037597320ebcfce43e37766b8b1b557cdd18)
- Second attempt (after `depositTo`): [`0xf7b5899b8518ed4c4c0121f9e176989dd83ca26eb266e96dbd7e272a2c304da6`](https://sepolia.etherscan.io/tx/0xf7b5899b8518ed4c4c0121f9e176989dd83ca26eb266e96dbd7e272a2c304da6)

Both emitted `CallbackFailure`. A call trace of the second transaction shows the proxy called `recordAlert` with the correct injected reactive address and then **ran out of gas** (`gas=0xb5d4f` / 744,783 forwarded, all consumed). On 2026 Sepolia a cold `SSTORE` costs ~110,000 gas, so writing `alertCount` plus the 8-field `Alert` struct costs ~887,000 gas. Official Getting Started examples still use a 1,000,000 `gasLimit`; after the proxy withholds `_extraGas` (150k) + `_maxChargeGas` (50k) and settlement, only ~745k reaches the board.

The fix was to redeploy PayWatch with `CALLBACK_GAS_LIMIT = 2,500,000` (forwards roughly 1.86M) and a new AlertBoard whose immutable `reactive` points at that contract, then `depositTo` 0.01 ETH of reserves before the demo transfer.
