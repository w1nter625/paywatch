# PayWatch — Reactive Omni Buildathon submission notes

- **Hackathon:** Reactive Omni Buildathon
- **Page:** https://dorahacks.io/hackathon/reactive-omni-buildathon
- **Track:** Set It and Forget It ($2,000 first / $250 runner-up, paid in REACT)
- **Deadline:** 2026-12-05 20:00 UTC = **2026-12-06 04:00 SGT**
- **Team:** solo, Wynnter
- **Repo:** (public GitHub link, filled in after the repo is created)
- **Demo video:** pending (≤ 3 minutes, screen recording + English TTS / captions; no on-camera appearance)

## Short description

PayWatch is a personal large-transfer watchdog you can leave running. A reactive contract on Lasna watches ERC-20 `Transfer` logs for a wallet and a threshold you choose. When a payment is at or above the cap, it requests a callback that records the event on an AlertBoard on Base Sepolia. No off-chain bot.

## What to include on DoraHacks

- Public open-source repository (this repo, MIT)
- Deployed addresses: MockUSD, PayWatchReactive, AlertBoard
- Transaction hashes for the full loop: origin `Transfer` on Base Sepolia → reactive `react` / `ThresholdHit` on Lasna → `AlertRecorded` callback on Base Sepolia
- Demo video under three minutes

## Status

Contracts and unit tests are written. Live testnet deploy is blocked on faucet tokens: Lasna lREACT is obtained by sending Sepolia or Base Sepolia ETH to the official faucet contracts. That claim still needs a testnet ETH faucet (many require a login). Do not buy ETH or REACT.
