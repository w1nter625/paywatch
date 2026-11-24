# PayWatch — DoraHacks BUIDL copy (do not submit until live txs are in)

Hackathon: Reactive Omni Buildathon  
Page: https://dorahacks.io/hackathon/reactive-omni-buildathon  
Track: **Set It and Forget It** ($2,000 first / $250 runner-up, paid in REACT)  
Deadline: 2026-12-05 20:00 UTC = **2026-12-06 04:00 SGT**  
Team: solo, Wynnter (DoraHacks @wynnter)  
Repo: https://github.com/w1nter625/paywatch  
Nothing below has been submitted. Do not post the video to YouTube or any social platform.

Live contract addresses and the origin → reactive → callback transaction hashes are **still pending** testnet ETH (then official lREACT). Judging requires those on-chain hashes; do not submit the BUIDL until they are filled in below.

---

## Paste-ready fields

### Project name
PayWatch

### One-line description / tagline
A personal large-transfer watchdog you can leave running: if a watched wallet moves an ERC-20 transfer at or above your cap, a reactive contract records it on-chain. No bot to keep online.

### Track
**Set It and Forget It**

### GitHub repository
https://github.com/w1nter625/paywatch

### Demo video
https://cdn.jsdelivr.net/gh/w1nter625/paywatch@gh-pages/demo.mp4

(Do not paste a github.com or releases URL — DoraHacks rejects those as video links.)

Local copy: `/workspace/competitions-2/reactive-paywatch/demo.mp4` (under three minutes, 1080p, H.264 + AAC, English `en-US-AndrewNeural` TTS, burned-in captions). No on-camera appearance. Slide-style walkthrough of the loop, authentication, and the passing Foundry suite. Re-cut with live explorer hashes after testnet deploy.

### Logo / cover
- Logo (1024×1024 PNG): `/workspace/competitions-2/reactive-paywatch/logo.png`  
  Also in the repo: https://github.com/w1nter625/paywatch/blob/main/logo.png
- Cover (1920×1080 PNG): `/workspace/competitions-2/reactive-paywatch/cover.png`  
  https://github.com/w1nter625/paywatch/blob/main/cover.png

Use the square logo if the form asks for a project logo. Use the 16:9 cover if it asks for a banner or cover image.

### Website / live demo (optional)
Repository URL, or the static page in `web/index.html`. There is no separate hosted app; the product is the on-chain loop.

### Tags (if asked)
`reactive` `lasna` `base-sepolia` `erc20` `alerts` `automation` `set-it-and-forget-it`

### Deployed addresses (fill after faucet + deploy.sh)
| Contract | Chain | Address |
|---|---|---|
| MockUSD | Base Sepolia (84532) | _pending_ |
| PayWatchReactive | Lasna (5318007) | _pending_ |
| AlertBoard | Base Sepolia (84532) | _pending_ |

Testnet deployer (public address only): `0xe9229A666D0B9f213429c407Ff730A9287FCA96E`

### Transaction hashes — full loop (fill after demo.sh)
| Leg | What to look for | Hash |
|---|---|---|
| Origin | Base Sepolia `MockUSD.Transfer` of 250 pUSD (above the 100 cap) | _pending_ |
| Reactive | Lasna `PayWatchReactive.ThresholdHit` | _pending_ |
| Callback | Base Sepolia `AlertBoard.AlertRecorded` (via callback proxy) | _pending_ |

Explorers: https://sepolia.basescan.org/ and https://lasna.reactscan.net/

### Detailed description (English, concise — paste into the BUIDL “project details” box)

**Problem.** People already screenshot “did this payment land?” or run a watcher script that dies when the laptop sleeps. That is a habit worth keeping, but not as an off-chain bot.

**Who it is for.** Anyone who wants a personal cap on a wallet’s ERC-20 transfers — incoming or outgoing — and wants the alert to keep working after they close the laptop.

**What we built.** PayWatch is a Set It and Forget It automation. A `PayWatchReactive` contract on Reactive Lasna subscribes to `Transfer` logs for a chosen token and wallet on Base Sepolia. If the amount is at or above a threshold you set, it requests a callback. `AlertBoard` on Base Sepolia records the event. The board accepts calls only from the official callback proxy, and only when the injected sender is the authorized reactive contract. Cooldown is in seconds (`block.timestamp`), as required on 200 ms Base Sepolia blocks.

**How it works.** The demo deploys a 6-decimal `MockUSD` (pUSD) so the full loop can be shown without a faucet-issued stablecoin. In production the same subscriber points at USDC or any other ERC-20. Deployment order follows the official docs: reactive contract first (it needs the token address), then the board (it needs the reactive address), then `setBoard`. The Foundry suite etches a mock system contract and covers subscribe-on-construct, incoming and outgoing hits, below-threshold / wrong-token / unwatched-wallet filters, cooldown, `onlySystem` / `onlyOwner`, no callback until the board is set, and AlertBoard authentication (14/14 passing).

**On-chain proof.** After testnet funding, `./scripts/deploy.sh` and `./scripts/demo.sh` produce the three hashes above: origin transfer, reactive `ThresholdHit`, and `AlertRecorded` callback.

### Short “problem / audience / how it works / track” blurb
(If the form has a shorter text box, use this.)

PayWatch is a personal large-transfer watchdog for the Set It and Forget It track. A Lasna reactive contract watches ERC-20 Transfer logs on Base Sepolia; if a watched wallet moves at or above your cap, an AlertBoard records it via the official callback proxy. No off-chain bot.

---

## DoraHacks form: fields you will likely have to fill in the browser

Inferred from DoraHacks public docs (default BUIDL form) and from this event’s own rules (public repo, deployed addresses, full-loop transaction hashes, demo video under three minutes, pick one listed track). The live form was not opened, and no BUIDL was submitted. Custom questions, if any, are only visible after login.

**Before the BUIDL form**

1. Sign in to DoraHacks as **@wynnter** (existing account). Connect GitHub `w1nter625` if the form offers it.
2. Open https://dorahacks.io/hackathon/reactive-omni-buildathon and click **Register** / **Join** if not already registered.
3. Click **Submit BUIDL** → **Create new BUIDL** (do not reuse another project). Wait until the address and hash tables above are filled.

**Typical required or expected BUIDL fields**

| Field | Required? | What to paste / upload |
|---|---|---|
| Project name | Yes | PayWatch |
| Tagline / one-liner | Yes | The one-line description above |
| Track | Yes | Set It and Forget It |
| GitHub / public repo | Yes | https://github.com/w1nter625/paywatch |
| Demo video URL | Yes | https://cdn.jsdelivr.net/gh/w1nter625/paywatch@gh-pages/demo.mp4 |
| Logo | Likely | `logo.png` (square) |
| Cover / banner | Sometimes | `cover.png` (16:9) |
| Website | Optional | repo URL |
| Description | Yes | The detailed description above |
| Contract addresses | Yes (for scoring) | Fill from `broadcast/addresses.env` after deploy |
| Transaction hashes | Yes (for scoring) | Origin + Lasna + callback; entries without them are not scored further |

---

## Official ways to get lREACT (for the operator, not the form)

Documented at https://dev.reactive.network/reactive-mainnet and in https://github.com/Reactive-Network/testnet-faucet. There is no login-free official drip of lREACT by itself. You first get Sepolia or Base Sepolia test ETH, then:

- Send test ETH (plain value transfer) to a faucet contract, or call `request(address)` with value.
- Ethereum Sepolia: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`
- Base Sepolia: `0x2afaFD298b23b62760711756088F75B7409f5967`
- Rate: **1 ETH → 100 lREACT**. Do not send more than **5 ETH** per transaction (max 500 lREACT; amounts above 5 ETH are lost).
- Example: `0.01` ETH → `1` lREACT, enough for the 0.05 lREACT constructor funding plus gas.

`./scripts/request-lreact.sh base 0.01ether` wraps the official `request(address)` call once the deployer has test ETH. Never send mainnet funds. Never buy ETH or REACT for this.

A site at `https://faucet.rnk.dev/` is mentioned in some community READMEs as a “Reactive Lasna faucet,” but it did not respond reliably when checked (TLS / 500). Treat the two contracts above as the official path.
