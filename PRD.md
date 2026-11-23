# Alarm Token: Product Requirements Document

**Project:** Alarm Token, cross-chain exit protection for LayerZero OFT token holders
**Event:** Reactive Omni Buildathon (5 Nov to 5 Dec 2026)
**Team:** Razaqi, Bayu, Aga, Raka (4 people)
**Version:** 1.0, 23 Nov 2026
**Status:** Build spec. Design decisions are final unless a gate (Section 14) fails. Open items are listed in Section 18.

---

## 0. How to read this document

### 0.1 Evidence labels

Every claim that is not a plain design decision carries one of these labels:

| Label | Meaning |
|---|---|
| **[Fact: source]** | Checked by us against a primary source or on-chain data. The source is named. |
| **[Secondary]** | Read by us in press or research write-ups, not confirmed on-chain or in primary docs. |
| **[Team claim]** | Comes from team documents. Not re-checked by us. |
| **[Inference]** | Our conclusion from facts. Not stated directly in any source. |
| **[Assumption]** | Not checked yet. Must be verified before we rely on it. |
| **[Opinion]** | A recommendation or judgment. |

### 0.2 Related documents

| File | Role |
|---|---|
| `PRD.md` (this file) | What we build, how, by whom, and when |
| `CLAUDE.md` | Working rules for humans and AI agents on this project |
| `alarm-token-final.md` | Full decision history and reasoning (Indonesian) |
| `reactive-omni-notes.md` | Hackathon rules and Reactive Network technical notes, with sources (Indonesian) |
| `catatan-risiko-alarm-token.md` | Detailed risk register A1–A12, B1–B7, C1–C3, and the draft questions for the organizers (Indonesian) |
| `keputusan-desain-alarm-palsu-alarm-token.md` | Decisions K1–K10 and sources S1–S12 (Indonesian) |

`rencana-mitigasi-alarm-token.md` is obsolete. Do not use it.

The research documents above are **not in this repo**. They live in `D:\Project\HACKATHON LAGI\` on Razaqi's machine.
Read them only when this PRD is not enough, and treat this PRD as the current spec if they disagree.

---

## 1. Summary

Alarm Token protects people who hold omnichain tokens (LayerZero V2 OFT) in their own wallets.

When a token's bridge trust settings are hijacked, attackers can mint unbacked tokens and dump them. Alarm Token
watches for the moment the hijack happens. A reactive contract on Reactive Network sees the change and triggers a
callback on Base Sepolia. The callback swaps each registered holder's tokens to a stablecoin and sends the proceeds
straight to the holder's own wallet.

- No bot and no server in the core loop.
- No permission or cooperation from the token issuer.
- Tokens stay in the holder's wallet until the exit runs.

**One-liner:** *When a token's bridge config is hijacked, your tokens exit to stablecoin automatically: no bot, no
server, no issuer permission.*

---

## 2. Problem

### 2.1 How the attack works

A LayerZero OFT token trusts one "peer" contract per remote chain, and a "delegate" that can change its messaging
configuration. Whoever controls those settings can make the token accept messages that mint tokens with no backing.
Once unbacked tokens are minted and sold, the price collapses and every honest holder loses value.

Plain-language version: the token is a shopping voucher used in City A and City B. City B's office only prints
vouchers when it receives a letter from its registered partner office. If a thief swaps the registered partner for a
fake office, the fake office can order billions of vouchers, and every voucher becomes worthless.

### 2.2 Evidence we checked ourselves

**GriffinAI (GAIN), BSC, 24 Sep 2025** [Fact: BSC on-chain data via public RPC and BscScan State tab]

| Event | Block | Time (UTC) |
|---|---|---|
| `setPeer(30101, 0xba15…efeb0)` on the GAIN contract, tx `0xf867a8e0…2d88` | 62339788 | 22:42:35 |
| First fake mint, tx `0xa85b18bd…e866` | 62341579 | 23:04:59 |

- Gap: 1,791 blocks, **1,344 seconds (about 22 minutes)**.
- The existing peer `0x2295…7d75` was replaced, not added from empty.
- `setPeer` and the fake mint happened on the **same chain** (BSC). The fake peer sat on EID 30101.
- Price impact: about 90% [Fact: REKT writes "obliterate GAIN's price by 90%" and quotes GoPlus "plummet over 90%"].

**The Sandbox (SAND), Base mainnet, 21–22 Aug 2026** [Fact: Base on-chain data via public RPC, checked 21 Nov 2026]

- Token: `0xac531Eb26Ca1d21b85126De8FB87E80E09002DcF` (has code, `symbol()` = SAND, `endpoint()` = `0x1a44…728c`).
- Block 50283177, **23:41:41 UTC**, tx `0x149eb0ee…aa237`: attacker `0x67624bfa…257e` calls the token with selector
  `0xcae9ca51` (`approveAndCall`). The endpoint emits **`DelegateSet(sender = token, delegate = attacker)`**.
- Block 50283189, **23:42:05 UTC (24 seconds later)**, tx `0xbddb102a…8fa9`: the attacker calls `lzReceive` on the
  endpoint. Tokens are minted, and `OFTReceived` is emitted with `srcEid` 30101.
- `DelegateSet` with the same values was emitted many more times during the attack. No `setPeer` was used.
- Not yet checked: whether `UlnConfigSet` or a library change happened, and how messages passed verification.
- [Secondary: crypto.news, avoid.net, eGamers quoting the 27 Aug post-mortem] No private key was leaked. About
  14.75M SAND (about US$675K) was drained from the Ethereum adapter. Minted-amount figures conflict between sources.
  Do not quote them.

### 2.3 Other incidents (context only, not claims)

| Incident | Pattern | Status |
|---|---|---|
| StakeDAO (vsdCRV), 2026 | Deployer key leaked, peer replaced, about 5.4T vsdCRV minted | [Team claim], also reported by crypto.news [Secondary] |
| Yala (YU), 2025 | 120M YU minted on Polygon, bridged to Ethereum and Solana, sold for 7.7M USDC | [Team claim]. Must be verified before it backs scenario (a) |
| KelpDAO (rsETH), Apr 2026 | Fake inbound message, 1-of-1 DVN setup, about US$300M | 1-of-1 DVN setup [Fact: three sources]. Not covered by the MVP |

**Claim rule:** the video and README may only claim protection for patterns that are covered **and** verified:
GriffinAI (peer change, S1) and The Sandbox (delegate change). Other incidents are context only.

---

## 3. Target users

Ordinary people who hold omnichain tokens **in their own wallet**. They cannot watch security news 24/7, and they do
not want to hand their wallet to a Telegram trading bot [Team claim]. Example of that risk: Banana Gun lost about
US$3M from 11 users in 2024 [Team claim: The Block].

### 3.1 User stories

1. As a holder, I register my token once, approve the executor, and set how much to sell and my slippage limits.
2. As a holder, when the token's peer or delegate is hijacked, my tokens are swapped to USDC and sent to my own
   wallet without me doing anything.
3. As a holder, if I chose to sell less than 100%, the rest is sold automatically once a mass mint confirms the
   attack.
4. As a holder, if the alarm was false, I buy back in with one click.
5. As a holder, I can see whether my protection is funded and active, and how fast past alarms were handled.
6. As a holder, I am warned at registration if the token's DVN setup is 1-of-1.
7. As a judge, I can run a full drill myself with my own wallet on testnet, without trusting the team's keys.

---

## 4. Hackathon context

### 4.1 Rules [Fact: Reactive blog, see `reactive-omni-notes.md` §1]

- Period: 5 Nov to 5 Dec 2026. The exact time and time zone of the deadline are not published. **We submit on
  4 Dec.**
- Submission on DoraHacks: public open-source repo, contract addresses, several tx hashes that show the full loop
  from origin event to callback, and a demo video **under 3 minutes**.
- Everything is built during the event. Older code is allowed only as a dependency.
- On Base Sepolia, measure time with timestamps, not block counts.
- Mainnet and testnet must never be mixed [Fact: Reactive docs].

### 4.2 Judging rubric [Fact: blog]

Four criteria, equal weight, scored 1–5:

| Criterion | What it means for us |
|---|---|
| **Execution** | Reactive tx and callback must be on-chain. Without them the entry is not judged at all. |
| **Integration** | How essential Reactive is. Our strongest point is cross-chain correlation: cause on chain A, action on chain B. |
| **Usefulness** | A real problem with real evidence (Section 2). |
| **Craft** | Quality of design, code, UX, and presentation. |

### 4.3 Tracks [Fact: DoraHacks Tracks tab, 18 Nov]

| | Every Second Counts (ESC) | Set It and Forget It (SIFI) |
|---|---|---|
| Title | "Low latency DeFi on Unichain Sepolia or Base Sepolia" | "Build something useful for yourself, on any supported chain" |
| Network | Lasna with Unichain Sepolia and/or Base Sepolia | Reactive mainnet or Lasna, any supported chain |
| Looking for | A working prototype and **measured end-to-end latency that shows why the idea needs Reactive Omni** | A tool you would actually leave running, a clear personal goal, a creative approach to event-based logic. "Latency matters less here than usefulness" |
| Prize | $2,000 / $250 | $2,000 / $250 |

### 4.4 Track decision rule

The track is chosen after gate G5 (latency of attack ordering B):

| G5 result | Track |
|---|---|
| Omni loop latency < ordering-B window < ~7 s | ESC |
| Ordering-B window < Omni loop latency | SIFI |
| Ordering-B window ≥ ~7 s | SIFI |

- ~7 s is the old Reactive block time [Fact: Reactive docs], not a measured loop latency.
- **Default while organizer questions are deferred:** if chain X is Ethereum Sepolia, submit to **SIFI**. The ESC
  brief only names Unichain Sepolia and Base Sepolia.
- [Opinion] The final track will most likely be SIFI.
- **Known SIFI weakness:** no team member holds OFT tokens, so "a clear personal goal" is weak. The pitch leans on
  "a tool you would leave running" and "creative event-based logic" instead. We do not claim personal use.

### 4.5 Competitive landscape [Fact: DoraHacks gallery screenshots, 19 Nov]

- 43 builds: 16 ESC, 18 SIFI, 9 AI.
- Protection themes are crowded, especially in SIFI. Examples: ExitGuard (×2), Tripwire dead-bolt, Pursestrings,
  AutoGuard, Stop-Loss Sentinel.
- ESC has 8 of 16 entries doing stop-loss or take-profit. ReactiveVaultGuard describes an "exploit-pattern watchdog".
- No visible entry mentions LayerZero, OFT, or peers. Descriptions are truncated, so this is a limited check.
- **Differentiator:** the only entry (as far as we can see) that reacts to bridge-trust hijacks of omnichain tokens,
  backed by on-chain evidence from two real incidents.

---

## 5. Guardrails (must never be lost)

| # | Value |
|---|---|
| **V1** | Exit to a **stablecoin**, not just a token transfer. The loss comes from price collapse. |
| **V2** | **Automatic and fast**, with no action from the user. |
| **V3** | **Cross-chain:** cause on chain A, action on chain B. Fully visible only in scenario (a). |
| **V4** | **No issuer permission:** works from the holder's side. |
| **V5** | **Non-custodial:** tokens stay in the user's wallet until the exit runs. |
| **V6** | **No bot or server** in the core loop. |

**Team criteria:** no mock data or mock features (simulations are labeled as such), a real problem with a specific
target user, an uncommon idea, a fit with the brief and rubric, a clear business model, a wow moment, and technical
depth.

---

## 6. Scope

### 6.1 MVP (must ship)

| ID | Feature |
|---|---|
| M1 | Registration on Base Sepolia: token, settings, approval, protection deposit, baselines |
| M2 | **S1:** alarm when a peer changes from baseline, on both chains |
| M3 | **DelegateSet:** alarm when the token's delegate changes from baseline, on both chains |
| M4 | Same-value `setPeer` and `DelegateSet` are ignored. No baseline means the first event is an alarm |
| M5 | Exit: swap to USDC on Base Sepolia, proceeds to the user, with a 3-step ladder and a user-selected failure mode |
| M6 | One callback per token, batched over users, with keeperless continuation through `Progress` events |
| M7 | **S2:** after S1, confirm the attack via `OFTReceived` from the changed EID, then sell the remainder |
| M8 | Reference price from pool events, with a maximum age and a user floor price as fallback |
| M9 | Dashboard: registration, status, warnings, contract health, latency table, one-click re-entry |
| M10 | DVN 1-of-1 warning at registration (read-only) |
| M11 | Drill scenarios (b) and (a) on testnet, with tx hashes in the README |
| M12 | Drill script judges can run (3a ii), an unregistered comparison wallet (3b), ordering B shown even if not caught (3c), false alarm and re-entry (3d) |
| M13 | **Self-serve judge drill** (built last): a judge deploys their own demo OFT, registers it, and triggers `setPeer` from their own wallet |
| M14 | Latency measurement: p50, p95, and n, using timestamps |

### 6.2 Stretch (only after the MVP works end to end)

| ID | Feature | Why stretch |
|---|---|---|
| X1 | **S1+**: alarm on weakened DVN config (`UlnConfigSet`) | No incident evidence yet. "Weakened" and which library to watch are undefined |
| X2 | **S2'**: first inbound message from a new peer with a large amount | Covered by S1 + S2 for now |
| X3 | **S3**: tokens received that were never sent ("phantom packet", KelpDAO pattern) | Complex. KelpDAO is not a config-change attack |
| X4 | Monitoring a real OFT on Reactive mainnet (SIFI only) | Needs real REACT and gas. Decide after G5 |

### 6.3 Out of scope

- Any backend server, keeper, or bot in the core loop (V6).
- An "attack" button that needs the team's owner key on a server, or a token with an open `setPeer`.
- Issuer announcements as a signal (K8: violates V4 and can be faked by the key holder).
- A fee taken from exit proceeds (conflicts with the executor invariant, Section 8.2).
- Mixing mainnet and testnet in one loop.

---

## 7. System architecture

### 7.1 Chains

| Chain | Chain ID | LayerZero EID | LZ status | Reactive callback proxy |
|---|---|---|---|---|
| Reactive Lasna | 5318007 | — | — | `0x8888888888888888888888888888888888888888` (system contract) |
| Base Sepolia | 84532 | 40245 | ACTIVE | `0x476F44b11F5C942c58f4c8E3d0300E5710743585` |
| Ethereum Sepolia | 11155111 | 40161 | ACTIVE | `0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4` |
| Unichain Sepolia | 1301 | 40333 | **DEPRECATED** (all four DVNs deprecated, one is LZDeadDVN) | `0x775c9B990ADe401060B78D0e98684eEf8d2466C1` |

[Fact: Reactive docs `/origins-and-destinations`; LayerZero metadata `/v1/metadata/deployments`, checked 19–20 Nov.
Use the `deployments` endpoint, not `/metadata/dvns`, which does not list Unichain testnet.]

- **Chain X** (the second chain, K1): Base Sepolia + Unichain Sepolia if G2 passes. Otherwise Base Sepolia +
  Ethereum Sepolia. [Opinion] Ethereum Sepolia is the likely outcome.
- Arbitrum Sepolia and Optimism Sepolia are **not** supported by Reactive testnet [Fact].
- Block times: Base Sepolia 200 ms, Unichain Sepolia 1 s, Reactive Omni ~1 s (was ~7 s) [Fact: docs and blog].

### 7.2 Components

| Component | Chain | Responsibility |
|---|---|---|
| `AlarmReactive` | Reactive Lasna | Subscribes to events, keeps baselines and the reference price, decides alarms, requests callbacks |
| `AlarmExecutor` | Base Sepolia | Holds registrations and settings, reads Base baselines, receives callbacks, runs batched exits, emits `Progress` |
| `BaselineReporter` | Chain X | Permissionless. Reads the chain-X token's `peers(eid)` and `endpoint.delegates(token)` and emits them as a baseline event |
| `DemoOFT` | Base Sepolia + chain X | A real LayerZero V2 OFT built by the team, used for the drills |
| `AttackerPeer` | Chain X (scenario b) or Base (scenario a) | Drill-only fake peer that sends mint messages after the peer is swapped |
| `DrillFactory` | Base Sepolia + chain X | Self-serve judge drill (M13): deploys a demo OFT owned by the caller |
| DEX pool | Base Sepolia | DemoOFT/USDC pool created and seeded by the team (G6) |
| Dashboard | Browser only | Next.js app. Reads chain data over RPC and sends transactions from the user's wallet. No backend |
| Scripts | Developer machine | Deploy, drill runner, gate experiments, latency measurement. Not part of the core loop |

### 7.3 Architecture diagram

```
             Base Sepolia (84532)                         Chain X (Unichain or Ethereum Sepolia)
  ┌────────────────────────────────────────┐        ┌──────────────────────────────────────┐
  │ DemoOFT (Base)  ── PeerSet, OFTReceived │        │ DemoOFT (X) ── PeerSet, OFTReceived  │
  │ EndpointV2      ── DelegateSet          │◄──LZ──►│ EndpointV2  ── DelegateSet           │
  │ AlarmExecutor   ── Registered, Progress │        │ BaselineReporter ── Baseline         │
  │ DEX pool        ── Swap (price)         │        └──────────────────┬───────────────────┘
  └───────┬───────────────────▲─────────────┘                           │ events
          │ events            │ callback (onAlarm / onConfirm)          │
          ▼                   │                                         ▼
  ┌──────────────────────────────────────────────────────────────────────────────────────┐
  │ AlarmReactive on Reactive Lasna (5318007)                                            │
  │ baselines[chain][token][eid] · delegate baseline · last price + Lasna timestamp      │
  │ react(): filter → compare to baseline → request callback → subscribe S2              │
  └──────────────────────────────────────────────────────────────────────────────────────┘

  Dashboard (browser) ── RPC reads + user-signed txs ──► AlarmExecutor, DEX router
```

### 7.4 Event subscriptions

| Event | Emitter | Chain | How subscribed | topic0 |
|---|---|---|---|---|
| `Registered(...)` | `AlarmExecutor` | Base | Static, at deploy | Our event |
| `Progress(token, cursor)` | `AlarmExecutor` | Base | Static, at deploy | Our event |
| `Baseline(...)` | `BaselineReporter` | X | Static, at deploy | Our event |
| `PeerSet(uint32 eid, bytes32 peer)` | Registered token | Base, X | **Dynamic**, added by `react()` when `Registered` arrives | `0x238399d427b947898edb290f5ff0f9109849b1c3ba196a42e35f00c50a54b98b` |
| `DelegateSet(address sender, address delegate)` | EndpointV2 | Base, X | Static, endpoint-wide (no indexed params). Filter `sender` in `react()` | `0x6ee10e9ed4d6ce9742703a498707862f4b00f1396a87195eb93267b3d7983981` |
| `OFTReceived(bytes32 indexed guid, uint32 srcEid, address indexed toAddress, uint256 amountReceivedLD)` | Token | Chain where the peer changed | **Dynamic**, added by `react()` after S1, with an expiry | `0xefed6d3500546b29533b128a29e3a94d70788727f0507505ac12eaf2e578fd9c` |
| Pool `Swap` | Pool (v3) or PoolManager (v4) | Base | Static. For v4, filter poolId in topic1 [Team claim, verify at G6] | Depends on G6 |

[Fact: topic0 values computed with `cast keccak` from the event signatures in LayerZero V2 source. The `PeerSet` and
`OFTReceived` hashes match logs we observed on mainnet.]

Subscription rules [Fact: Reactive docs]:
- Only exact matching. No ranges and no OR. One `subscribe()` per combination.
- Duplicate subscriptions still cost gas.
- `unsubscribe()` silently fails unless all six arguments match exactly. Use one internal helper for both.
- Subscriptions live in the node, not in contract storage, so they cannot be read on-chain. Track them yourself.

### 7.5 Flows

#### F1. Registration (Base Sepolia, user wallet)

1. The dashboard reads the token's DVN config and shows a warning if it is 1-of-1 (M10).
2. The user approves `AlarmExecutor` for the token.
3. The user calls `register(...)` with: token on Base, token address on chain X, EIDs, sell portion (default 100%),
   slippage (default 20%), failure mode (default "second cap"), floor price, and a protection deposit in ETH.
4. The executor requires a non-zero token balance and an allowance (anti-spam).
5. The executor reads `token.peers(eidX)` and `endpoint.delegates(token)` on Base, then emits `Registered` with these
   baselines.
6. `AlarmReactive` receives `Registered`, stores the Base baselines, and subscribes to `PeerSet` on both token
   addresses (once per token).
7. Anyone (the dashboard does it for the user) calls `BaselineReporter.report(tokenX, eidBase)` on chain X. It emits
   the chain-X peer and delegate baseline. `AlarmReactive` stores it.

#### F2. Alarm (S1 or DelegateSet)

1. `react()` receives `PeerSet` from a tracked token, or `DelegateSet` whose `sender` is a tracked token.
2. Compare with the baseline:
   - Equal: ignore.
   - No baseline: treat as an alarm.
   - Different: alarm, and update the baseline.
3. On alarm: request a callback `onAlarm(...)` to `AlarmExecutor` on Base, with the reason, origin chain, reference
   price, and reference timestamp.
4. If the alarm came from `PeerSet`: subscribe to `OFTReceived` on that token, on that chain, for S2.
5. `react()` never reverts. Non-matching logs are ignored [Fact: docs, reverts are charged in full].

#### F3. Exit (Base Sepolia, inside the callback)

1. Guards: `onlyServiceProvider` and `onlyCallbackSender(alarmReactive)` [Fact: docs].
2. Process registered users for that token from `cursor`, up to a batch size set from measured gas (G3/G4).
3. Per user: amount = `min(balance at callback, allowance)` × portion.
4. Ladder (K4, default): 100% at 20% slippage → 50% at 20% → the rest at 50% → stop.
   - Failure modes chosen at registration: **Stop**, **Second cap** (default ladder above), or **Any price**.
   - `minOut` is based on the reference price. If the reference is older than the maximum age, the user's floor
     price is used instead.
5. Swap output goes **directly to the user's address**.
6. Each result is logged with `ExitExecuted` or `ExitFailed`. **No revert** at callback level, because failed
   callbacks are still charged [Fact: docs].
7. If users remain, emit `Progress(token, nextCursor)`. `AlarmReactive` reacts and requests the next `onAlarm` batch.
   This is a keeperless loop.

#### F4. Confirmation (S2)

1. After S1, `OFTReceived` from the same token arrives with `srcEid` equal to the EID whose peer changed.
2. `AlarmReactive` requests `onConfirm(...)`. The executor sells the remainder for users with a portion under 100%.
3. The S2 subscription expires. The expiry mechanism is open (Section 18).
4. In scenario (a), fake tokens minted on chain X are bridged to Base. The S2 subscription is on chain X, where the
   peer changed.

#### F5. Re-entry

The dashboard builds a USDC → token swap for the user, signed by the user. No executor and no backend involved (K9).

### 7.6 Drill scenarios

All roles on testnet (issuer, attacker, holder) are played by the team, and we say so.

| Scenario | What happens | Status |
|---|---|---|
| **(b)** Peer swapped on Base | Fake peer on chain X sends a mint message. Fake tokens are minted on Base. Same pattern as GriffinAI | MVP, built first |
| **(a)** Peer swapped on chain X | Fake peer on Base sends a mint message to X. Fake tokens are minted on X, bridged to Base through the legitimate OFT path, and dumped on Base. V3 is fully visible | **MVP, mandatory** |
| **Delegate** | Owner calls `setDelegate` to a new address, then the fake mint follows. Only the signal is replicated, not The Sandbox's `approveAndCall` bug | MVP |

Conditions for scenario (a):
1. G2 must work in **both directions** (Base → X and X → Base).
2. Yala must be verified. If not, the video calls (a) a plausible variant, not a real incident.
3. In drill (a), the team chooses to bridge fake tokens to Base. There is no natural arbitrage on testnet. Say so.
4. G5 is adapted for (a).
5. If two-way G2 fails, re-evaluate Alarm Token against the fallback idea (Backstop) at that point.

**Video order [Opinion]:** GriffinAI data → The Sandbox data → scenario (b) → scenario (a) → false alarm and
re-entry.

---

## 8. Smart contract specifications

Names and signatures below are proposals. The owner of each contract may refine them, but the behavior is fixed.

### 8.1 `AlarmReactive` (Reactive Lasna)

- Inherits `AbstractReactive` from `reactive-lib-omni` [Fact: library structure, `reactive-omni-notes.md` §2, §12].
- Use the **Omni** API, not Legacy:
  - `onlySystem` on `react()`.
  - `SYSTEM.subscribe(...)`.
  - `SYSTEM.requestCallbackV_1_0(...)`.
  - **Not** `vmOnly`, `service.subscribe`, or `emit Callback`.
- The official demo repo is Legacy and must not be used as a template [Fact: notes §2].
- **Callback payload:** the first argument must be `address(0)`. Reactive overwrites it with the reactive contract
  address [Fact: docs].
- Callback `gasLimit` ≥ 100,000. Requests below that are dropped [Fact: docs].
- `react()` gas must stay under the 900,000 reactive-tx limit [Fact: docs].
- Funded with lREACT. Expose `coverDebt()`. Any debt stops all execution silently [Fact: docs].
- Owner-only setter for the executor address (deploy order: reactive, then executor, then set) [Fact: docs].

State:
```
peerBaseline[chainId][token][eid]   -> bytes32 (+ exists flag)
delegateBaseline[chainId][token]    -> address (+ exists flag)
tokenPair[chainId][token]           -> (baseToken, chainX token, eids)
lastPrice, lastPriceTimestamp       -> uint256 (Lasna block.timestamp; LogRecord has no origin timestamp)
s2Active[chainId][token]            -> (srcEid, expiry)
```

### 8.2 `AlarmExecutor` (Base Sepolia)

- Inherits `AbstractCallback(callbackProxy, alarmReactive)`. Both values are immutable. A wrong value means
  redeploying [Fact: docs].
- Every callback entry point uses `onlyServiceProvider` and `onlyCallbackSender(alarmReactive)`.
- Callback cost is charged to this contract in Base Sepolia ETH [Fact: docs]. It is funded by user protection
  deposits (business model, Section 13). The exact payment mechanics are verified at G4 [Assumption].

Functions (proposal):
```
register(baseToken, tokenX, eidBase, eidX, portionBps, slippageBps, failureMode, floorPrice) payable
updateSettings(...)
unregister(token)
onAlarm(address rvm, address token, uint8 reason, uint256 refPrice, uint256 refTs, uint256 cursor)  // callback
onConfirm(address rvm, address token, uint256 cursor)                                               // callback
coverDebt()
```

Events (proposal): `Registered`, `Unregistered`, `ExitExecuted`, `ExitFailed`, `Progress`, `ExitCompleted`.

**Invariants (each must have a Foundry invariant or fuzz test):**
1. Exit proceeds are only ever sent to the address of the user whose tokens were sold.
2. The executor has exactly one way to move user tokens: swap to the stablecoin, output to that user.
3. The executor never takes more than `min(balance, allowance)` from a user.
4. Callback entry points cannot be called by anyone except the proxy with the correct reactive sender.
5. Callback paths never revert because of a single user's failure.

### 8.3 `BaselineReporter` (chain X)

- `report(address token, uint32 remoteEid)`. Permissionless.
- Reads `IOAppCore(token).peers(remoteEid)` and `endpoint.delegates(token)`. Both are public getters
  [Fact: `OAppCore.sol` `peers`, `EndpointV2.sol` `delegates`].
- Emits `Baseline(token, remoteEid, peer, delegate)`. Values are read on-chain, never taken from user input.

### 8.4 `DemoOFT`, `AttackerPeer`, `DrillFactory`

- `DemoOFT`: a standard LayerZero V2 OFT. `OFT._credit` mints, so `Transfer` from the zero address and `OFTReceived`
  are emitted on receive [Fact: `OFT.sol`, `OFTCore.sol`]. No custom backdoors.
- `AttackerPeer`: drill-only. Labeled clearly in code and README.
- `DrillFactory`: deploys a `DemoOFT` owned by the caller, wires peers, and seeds a small pool position if needed.
  It needs per-wallet limits. Callback costs are covered by the judge's own protection deposit.
- LayerZero contracts use `pragma solidity ^0.8.20`. `reactive-lib-omni` uses `^0.8.29` [Fact: source files]. Pin
  one compiler version that satisfies both.

### 8.5 DEX (G6)

- Uniswap v4 PoolManager on Base Sepolia: `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` [Fact: Uniswap docs, has code].
- Uniswap v3 Factory on Base Sepolia: `0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24` [Fact: Uniswap docs, has code].
- USDC on Base Sepolia: `0x036CbD53842c5426634e7929541eC2318f3dCF7e` [Fact, limited: address from a search restricted
  to developers.circle.com, `symbol()` = "USDC" on-chain].
- **Open:** v3 or v4, pool size, `Swap` event format, poolId position. The pool for DemoOFT must be created and seeded
  by the team, because the token is ours.

---

## 9. Dashboard specification

**Stack:** Next.js, TypeScript. Wallet and chain access with wagmi + viem [Opinion: proposed, the frontend owner may
change it]. Frontend only. Reads events over RPC and sends transactions from the user's wallet.

| Screen | Content |
|---|---|
| **Register** | Token picker, chain X token, portion, slippage, failure mode, floor price, protection deposit. DVN 1-of-1 warning (M10). Warning when portion < 100%: "the remainder is sold automatically only if a mass mint is confirmed (S2)". Calls `BaselineReporter` on chain X |
| **My protection** | Status per token, "X of Y protected" (balance vs allowance), current baselines, "expansion?" label when a new EID appears |
| **Activity** | Alarms, exits, failures, and re-entry, with tx hashes on every chain |
| **Latency** | Per alarm: origin event time, reactive tx time, callback time. p50, p95, n |
| **Health** | `debt()` and `reserves()` for `AlarmReactive` and `AlarmExecutor`, with a red indicator below a threshold [Fact: a contract in debt stops without an error] |
| **Re-enter** | One-click USDC → token swap from the user's wallet |
| **Drill** (M13) | Self-serve judge drill: deploy my demo token, register, trigger `setPeer` or `setDelegate`, watch the loop. Labeled as a drill |

UX rules:
- Every number shown links to its on-chain source (tx hash or contract read).
- No fake or placeholder data. Empty states say "no data yet".
- Network mismatch is detected and blocked. No mainnet chains in the app.

---

## 10. Off-chain tooling (not part of the core loop)

| Tool | Purpose |
|---|---|
| Foundry deploy scripts | Deploy and wire all contracts per chain. Write addresses to `deployments/<chain>.json` |
| Gate experiments | G1, G2, G4, G6 scripts with logged tx hashes |
| Drill runner (M12, 3a ii) | Runs scenarios (b), (a), delegate, ordering B, and false alarm end to end. Judges can run it with their own keys |
| Latency tool (M14) | Reads block timestamps of the origin tx, reactive tx, and callback tx. Uses `getCallbacks(txHash)` on the system contract. Outputs p50, p95, n |
| Funding helpers | lREACT faucet, `depositTo`, `coverDebt`, debt and reserve checks |

These tools never sit in the protection path. If they all stop, protection still works (V6).

---

## 11. Tech stack

| Layer | Choice | Note |
|---|---|---|
| Contracts | Solidity, **Foundry** (forge, cast, anvil) | Foundry is already installed on the machine this PRD was written on. Fuzz and invariant tests are needed for Section 8.2 |
| Reactive | `reactive-lib-omni` (`AbstractReactive`, `AbstractCallback`, `AbstractPayer`) | Install command and remapping are not documented [Fact: notes §2]. Resolve at G1. The Reactive MCP `get_rc_template` returns a Foundry template |
| LayerZero | LayerZero V2 OApp/OFT contracts | Exact package name and version pinned at G2 [Assumption] |
| DEX | Uniswap v3 or v4 on Base Sepolia | Decided at G6 |
| Frontend | Next.js, TypeScript, wagmi + viem (proposed) | No backend |
| Scripts | Foundry scripts and/or TypeScript + viem | Owner's choice |
| Tooling | Reactive MCP (`https://mcp.rnk.dev/mcp`) for diagnosis | Docs warn generated code can be wrong. Review fund-moving code by hand |
| CI | GitHub Actions: `forge build`, `forge test`, frontend lint and build | |

---

## 12. Repository structure

```
alarm-token/
├── README.md                    # English. Judge-facing: problem, evidence, how to verify, tx hashes
├── PRD.md
├── CLAUDE.md
├── LICENSE                      # Open-source license (required: public open-source repo)
├── .env.example                 # Never commit .env
├── .github/workflows/ci.yml
├── contracts/                   # Foundry project
│   ├── foundry.toml
│   ├── remappings.txt
│   ├── src/
│   │   ├── reactive/AlarmReactive.sol
│   │   ├── executor/AlarmExecutor.sol
│   │   ├── reporter/BaselineReporter.sol
│   │   ├── demo/DemoOFT.sol
│   │   ├── demo/AttackerPeer.sol
│   │   ├── demo/DrillFactory.sol
│   │   ├── interfaces/
│   │   └── libraries/
│   ├── test/
│   │   ├── unit/
│   │   ├── fuzz/
│   │   └── invariant/           # Section 8.2 invariants
│   ├── script/                  # Deploy*.s.sol, Drill*.s.sol, Gate*.s.sol
│   └── lib/                     # forge dependencies
├── app/                         # Next.js dashboard
│   ├── src/
│   └── package.json
├── scripts/                     # Drill runner, latency tool, funding helpers
├── deployments/                 # <chain>.json with deployed addresses
└── docs/
    ├── architecture.md
    ├── drill-guide.md           # How a judge runs the drill
    ├── latency-report.md        # G5 results: p50/p95/n
    ├── gates.md                 # G1–G6 results with tx hashes
    └── tx-hashes.md             # Full-loop evidence for submission
```

---

## 13. Business model

**Decided:**
- **Core:** users prepay a **protection deposit** that covers callback costs on Base and reactive costs. This is the
  real cost structure: callbacks are charged to the executor in the destination chain's native token, and the
  reactive contract needs REACT [Fact: Reactive docs]. It fits the health panel (`debt()`, `reserves()`).
- **README only, as future direction, not a claim:** selling to token issuers as a trust signal ("protected by
  Alarm Token") with paid coverage for their holders.
- **Not used:** a fee per exit taken from proceeds. It would break executor invariant 1.

---

## 14. Gates (must pass before full build)

| Gate | Content | Status |
|---|---|---|
| **G1** | Basic loop: event → `react()` on Lasna → callback to a dummy on Base Sepolia. Proof: `getCallbacks(txHash)`. Also: (i) `react()` can subscribe dynamically, (ii) the `Progress` loop runs without a bot, (iii) `BaselineReporter` events are received, (iv) the frequency of `DelegateSet` on the testnet endpoints | ⬜ |
| **G2** | OFT messages sent and executed in **both directions** (Base → X and X → Base). Try Base ↔ Unichain Sepolia first, then Base ↔ Ethereum Sepolia the same day if it stalls. **Both fail:** switch to Backstop. **One direction only:** re-evaluate Alarm Token vs Backstop | ⬜ |
| **G3** | `PeerSet` signature (✅ from GAIN mainnet, recheck on our OFT). `OFTReceived` and DVN config reads on a real deployment. Gas of the 3-step swap ladder against the callback limit | 🟡 |
| **G4** | Executor gas, proxy `_extraGas` and `_maxChargeGas`, batch size. Callback ≥ 100,000 gas. Payment mechanics | ⬜ |
| **G5** | Attack orderings A and B for scenario (b), then adapted for (a). Measure with timestamps, report p50/p95/n. GriffinAI data ✅ | 🟡 |
| **G6** | DEX on Base Sepolia: pool, liquidity, `Swap` event format, poolId position. Addresses ✅ | 🟡 |

**Ordering A** = attacker changes the peer, then sends the fake message. **Ordering B** = attacker prepares the fake
message first, then changes the peer and executes immediately. LayerZero V2 stores DVN attestations without
checking the peer; the peer is checked at `commitVerification` and `lzReceive`, which anyone can call [Fact: source,
S12]. That ordering B works is partly [Inference], so it is tested at G5.

**What can change because of a gate:** K1 and scenario (a) (G2), reference price and event format (G6), the swap
ladder and batch size (G3/G4), and the track (G5).

---

## 15. Team and roles

Roles follow each person's stated area. Assignments inside each area are proposals [Opinion]; the team can swap them.

| Person | Area | Owns | Supports |
|---|---|---|---|
| **Razaqi** | Smart contracts | `AlarmExecutor`, `DemoOFT`, `AttackerPeer`, `BaselineReporter`, `DrillFactory`, invariant and fuzz tests, compiler and dependency pinning | Reviews `AlarmReactive` |
| **Aga** | Backend | `AlarmReactive` (the event-processing logic is the system's "backend", because V6 forbids a server). Gate experiments G1, G2, G4, G5. Deploy scripts, `deployments/`, drill runner, latency tool, CI, funding | Pairs with Razaqi on cross-contract interfaces |
| **Bayu** | Frontend | Dashboard (all screens in Section 9), wallet flows, DVN warning reads, latency and health views, self-serve drill UI | Usability testing with Raka |
| **Raka** | Marketing, branding, demo video | Name and visual identity, video script and recording (< 3 min), README narrative and pitch, DoraHacks BUIDL page, claim review against Section 2.3, gallery re-check before submission, Yala verification, judge guide (faucets, testnet ETH) | First outside tester of the drill flow |

**Note on Aga's role:** there is no server in the protection path. If Aga is not comfortable writing Solidity,
Razaqi takes `AlarmReactive` and Aga keeps gates, scripts, latency, CI, and deployment. Confirm this in the first
team sync.

**Critical path [Opinion]:** G1 and G2 decide whether the project continues. Razaqi and Aga both work on them first.

---

## 16. Timeline (today is 23 Nov; submit on 4 Dec)

| Dates | Phase | Exit criteria |
|---|---|---|
| 23–24 Nov | **Setup and gates** | Repo, CI, funded wallets (Base, Eth, Unichain Sepolia ETH; lREACT). G1 passed. G2 two-way passed or the fallback decided. G6 pool created. G4 numbers read |
| 25–28 Nov | **Core loop** | `AlarmReactive` + `AlarmExecutor` + baselines + `Progress` loop. Scenario (b) end to end with tx hashes. Delegate drill. Dashboard: register, status, health |
| 29 Nov–1 Dec | **Cross-chain and confirmation** | Scenario (a) end to end. S2. Same-value ignore. G5 latency report. DVN warning. Re-entry. Track decided from G5 |
| 1–3 Dec | **Judge experience** | Self-serve drill (M13). Drill runner. README, `docs/`, tx-hash list. Video recorded and edited |
| 3–4 Dec | **Freeze and submit** | Bug fixes only. Contracts funded for the judging window. Submission on 4 Dec |

**Kill and fallback rules:**
- G2 fails in both directions by 24 Nov → switch to Backstop.
- G2 works in one direction only → re-evaluate against Backstop the same day.
- Running out of time: cut in this order: M13 (judge drill UI, keep the script) → M10 (DVN warning) → S2 → the `Progress`
  continuation (fall back to a fixed small batch). Never cut: the full loop on-chain, scenario (b), the executor
  invariants, or the video.

---

## 17. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| No reactive tx + callback on-chain | **Entry not judged** | G1 first. Keep contracts funded. Health panel |
| G2 fails in one or both directions | Scenario (a) or the project fails | Two chain options tested on day 1. Backstop fallback |
| A contract falls into debt during judging | Loop silently stops | Fund generously. `coverDebt()`. Check `debt()` daily until judging ends |
| Wrong `callbackSender` or proxy at deploy | Callbacks always fail | Deploy script reads addresses from `deployments/`. Test with G1 dummy first |
| Endpoint-wide `DelegateSet` subscription is expensive | Reserves drain | Measure the event rate at G1. Fund accordingly |
| False alarms (legit peer expansion or delegate change) | User sells unnecessarily | Default 100% is a deliberate trade-off (B3). Same-value ignore. Portion setting. One-click re-entry. "Expansion?" label |
| Price already fell more than the slippage cap | Exit fails | Ladder and failure modes. Shown on the dashboard |
| Ordering B is faster than our loop | Not caught | Shown honestly (3c). Track rule in Section 4.4 |
| Network not allowed by the ESC brief | Disqualification risk in ESC | Default to SIFI with Ethereum Sepolia |
| SIFI "personal goal" fit is weak | Lower score | Lean on "tool you'd leave running" and event-logic creativity. No false claims |
| Unverified claims in video or README | Credibility loss | Claim rule in Section 2.3. Raka reviews against this PRD |
| Crowded protection theme | Harder to stand out | Lead with the bridge-hijack angle and the two on-chain incident timelines |

Full register: `catatan-risiko-alarm-token.md` (A fatal, B score-reducing, C track-moving).

---

## 18. Open items

| # | Item | Default until decided | Decided by / when |
|---|---|---|---|
| 1 | Questions to organizers (ESC with Ethereum Sepolia; self-seeded pool; track choice at submission; team size; judging window; deadline time zone) | Deferred. Defaults: SIFI if Ethereum Sepolia, own pool, submit 4 Dec, keep contracts funded for days after | Team, before submission |
| 2 | Approval policy (B5): approval = balance at registration, unlimited, or user choice | User choice, default "balance at registration" with an "X of Y protected" view | Team, before coding registration |
| 3 | Chain X | Per G2 | G2 |
| 4 | Uniswap v3 or v4 | Per G6 | G6 |
| 5 | S2 "large amount" threshold (the reactive contract cannot read `totalSupply` [Inference]) | Any `OFTReceived` from the changed EID after S1 counts | G3 |
| 6 | S2 subscription expiry mechanism | Unsubscribe on `ExitCompleted` | G1/G3 |
| 7 | Maximum age of the reference price | To be set from G5/G6 data | G5 |
| 8 | Batch size per callback | From measured gas | G3/G4 |
| 9 | Yala verification (backs scenario (a)) | Without it, (a) is a "plausible variant" | Raka |
| 10 | Mainnet monitoring of a real OFT for SIFI | Not planned | After G5 |
| 11 | Gallery re-check before submission | — | Raka, 3 Dec |
| 12 | Which file is the single living document: `PRD.md` or `alarm-token-final.md` | Both are kept until the team decides | Team |

---

## 19. Acceptance criteria (definition of done for submission)

- [ ] Public open-source repo, built during the event, with a license.
- [ ] All contracts deployed on testnet only (Lasna + Base Sepolia + chain X). Addresses in `deployments/` and README.
- [ ] Full-loop tx hashes for scenario (b), scenario (a), and the delegate scenario: origin event → reactive tx →
      callback → swap → USDC at the user.
- [ ] An unregistered comparison wallet shown next to a protected one.
- [ ] A false alarm with one-click re-entry shown.
- [ ] Ordering B shown, even if it is not caught.
- [ ] Latency report with p50, p95, and n, measured with timestamps.
- [ ] Executor invariant tests pass in CI.
- [ ] Dashboard shows health (`debt`/`reserves`) and has no placeholder data.
- [ ] Drill runner script works from a clean clone with the judge's own keys.
- [ ] Video under 3 minutes, every claim backed by Section 2 or our own measurements.
- [ ] Track chosen per Section 4.4.
- [ ] Contracts funded to stay active through the judging window.

---

## 20. Appendix

### 20.1 Reactive Network facts [Fact: `reactive-omni-notes.md`, from official docs]

- Lasna: chain ID 5318007, RPC `https://lasna-rpc.rnk.dev/`, explorer `https://lasna.reactscan.net/`, token lREACT.
- System contract: `0x8888888888888888888888888888888888888888`.
- lREACT faucet: send Sepolia ETH to `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434` (Ethereum Sepolia) or
  `0x2afaFD298b23b62760711756088F75B7409f5967` (Base Sepolia). 1 ETH = 100 lREACT. **Maximum 5 ETH per tx; anything
  above is lost.**
- Reactive tx gas limit 900,000. Callback minimum 100,000 gas.
- Failed executions are charged in full. Any debt above zero stops execution.
- `LogRecord` fields: `chainId, contractAddress, topic0..topic3, data, blockNumber, opCode, blockHash, txHash,
  logIndex`. No origin timestamp.
- Check debt and reserves: `cast call <system or proxy> "debt(address)" <contract>` and `"reserves(address)"`.
- Check callbacks: `cast call <system> "getCallbacks(uint256)(...)" <reactiveTxHash>`. An empty array means "not
  recorded yet", not "failed".
- MetaMask: turn off Smart Transactions for Reactive.

### 20.2 Event topic0 reference

| Event | topic0 |
|---|---|
| `PeerSet(uint32,bytes32)` | `0x238399d427b947898edb290f5ff0f9109849b1c3ba196a42e35f00c50a54b98b` |
| `DelegateSet(address,address)` | `0x6ee10e9ed4d6ce9742703a498707862f4b00f1396a87195eb93267b3d7983981` |
| `OFTReceived(bytes32,uint32,address,uint256)` | `0xefed6d3500546b29533b128a29e3a94d70788727f0507505ac12eaf2e578fd9c` |
| `OFTSent(bytes32,uint32,address,uint256,uint256)` | `0x85496b760a4b7f8d66384b9df21b381f5d1b1e79f229a47aaf4c232edc2fe59a` |
| `UlnConfigSet(address,uint32,(uint64,uint8,uint8,uint8,address[],address[]))` | `0x82118522aa536ac0e96cc5c689407ae42b89d592aa133890a01f1509842f5081` |
| `Transfer(address,address,uint256)` | `0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef` |

### 20.3 Reading a token's DVN config (M10)

1. `endpoint.getReceiveLibrary(oapp, srcEid)` returns `(lib, isDefault)`.
2. `lib.getUlnConfig(oapp, srcEid)` returns the effective config with defaults merged: `confirmations`,
   `requiredDVNCount`, `optionalDVNCount`, `optionalDVNThreshold`, `requiredDVNs`, `optionalDVNs`.
3. `getAppUlnConfig` returns only the app's own config, without defaults.

[Fact: `MessageLibManager.sol`, `UlnBase.sol`. That `ReceiveUln302` exposes `getUlnConfig` through `ReceiveUlnBase`
is an inference from the import chain. Verify with a real call at G3.]

### 20.4 Why Alarm Token over the fallback idea (Backstop)

- Integration: cross-chain correlation is Reactive's core. Remove Reactive and the idea stops working.
- Stronger problem evidence (two on-chain incident timelines).
- Weaker outside competitors. Backstop has direct comparators (B.Protocol, Liquity Stability Pool, Compound III),
  and its Reactive part could be replaced by a keeper.
- Backstop remains the fallback if G2 fails.
