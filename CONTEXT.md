# CONTEXT.md: Current status and next steps

Last updated: 26 Nov 2026. Update this file whenever the status changes (gates passed, contracts deployed, decisions
changed).

Read `PRD.md` and `CLAUDE.md` before this file.

---

## 1. Where the project stands

- **Deadline:** submit on **4 Dec 2026** (event ends 5 Dec, time zone not published). 8 days left (26 Nov).
- **Schedule: behind.** `PRD.md` §16 planned G1, G2, and G6 for 23–24 Nov and the core loop for 25–28 Nov. No gate has
  run yet, and the core contracts (`AlarmReactive`, `AlarmExecutor`) do not exist yet.
- **Track: SIFI (Set It and Forget It)**, decided by Razaqi on 25 Nov. Chain X is Ethereum Sepolia; G2 goes straight
  there. ESC is a later, config-only option, only if G5 latency supports "why Omni" and DevRel answers the follow-up
  questions (`PRD.md` §4.4). Organizers confirmed that ESC covers only Unichain Sepolia + Base Sepolia, that testing on
  Lasna is enough (no mainnet), and that prizes are paid on Reactive mainnet with minimal KYC.
  [Fact: Reactive DevRel, Telegram, 23 Nov]
- **Design:** final in `PRD.md`. Reasoning (Indonesian) in `D:\Project\HACKATHON LAGI\alarm-token-final.md`.
- **Deployed:** nothing. `deployments/` is empty and `docs/gates.md` has no data.

### Code in `main`

| Area | What exists | PR |
|---|---|---|
| Setup | Foundry project, pinned dependencies, solc 0.8.30 / `prague`, CI (`forge build` + `forge test`) | #2 |
| `DemoOFT` | Standard LayerZero V2 OFT for drills | #2 |
| `BaselineReporter` | Chain-X baseline event, endpoint fixed at deploy, rejects tokens on another endpoint | #12 |
| `ExitMath` | `exitAmount`, `minOut`, `effectivePrice` (pure library, fuzzed). Not the ladder | #15 |
| G2 scripts | `DeployDemoOFT`, `WireDemoOFT`, `SendDemoOFT` | #7, #11 |
| G6 scripts | `CreateDemoPool`, `SwapDemoPool` (Uniswap v3), Base Sepolia fork rehearsal | #10 |
| Deploy tooling | `TestnetGuard` (testnet chains, per-chain LayerZero endpoint), `DeploymentRecorder` (`deployments/<chain>.json` on `--broadcast`) | #7, #14 |

Open PRs: #16 (`BaselineReporter` deploy records its address, README command fix), #17 (`AttackerPeer`).

Not started: `AlarmReactive` (Aga), `AlarmExecutor` (Razaqi), `DrillFactory` (Razaqi), executor invariant tests.

## 2. Already verified (do not redo, but re-check on our own deployments)

| Item | Result | Source |
|---|---|---|
| `PeerSet` topic0 | `0x238399d4…b98b`, EID and peer in `data` | GAIN mainnet logs, `cast keccak` |
| `DelegateSet` | `DelegateSet(address sender, address delegate)`, no indexed params, emitted by EndpointV2 | LayerZero V2 source |
| `OFTReceived` | Emitted on every inbound OFT message, carries `srcEid` | LayerZero V2 source, Sandbox logs |
| `endpoint.delegates(oapp)`, `peers(eid)` | Both public getters | LayerZero V2 source |
| DVN config read | `getReceiveLibrary` then `getUlnConfig` | LayerZero V2 source (call not yet tested) |
| GriffinAI timeline | `setPeer` → fake mint: 1,344 s | BSC on-chain data |
| The Sandbox timeline | `DelegateSet` → first fake mint: 24 s, no `setPeer` | Base mainnet on-chain data |
| LayerZero EndpointV2 | Base and Ethereum Sepolia `0x6EDC…f10f`; Unichain Sepolia `0xb881…5035` (DEPRECATED) | Metadata + `eid()` on-chain, 25 Nov (`PRD.md` §7.1) |
| Uniswap v3 on Base Sepolia | Factory, NonfungiblePositionManager, SwapRouter02 verified on-chain | Uniswap docs + RPC, 25 Nov |
| USDC on Base Sepolia | `0x036CbD53842c5426634e7929541eC2318f3dCF7e`, `symbol()` = USDC, 6 decimals | Circle docs + RPC |
| Lasna EVM | PUSH0, TSTORE/TLOAD, MCOPY work. No blob support: `BLOBBASEFEE` crashes the RPC | `eth_call` probes, 23 Nov |
| Reactive API | Use Omni API from `reactive-lib-omni`. The official demo repo is Legacy | Reactive docs and repos |

Fork rehearsal (not evidence): a Uniswap v3 DemoOFT/USDC pool on a Base Sepolia fork emitted `Swap` with two indexed
params (sender, recipient).

## 3. Not known yet (must be resolved by doing, not guessing)

- Whether OFT messages work both ways between Base Sepolia and Ethereum Sepolia (G2).
- Uniswap v3 on-chain result and the real `Swap` event (G6). v4 was not evaluated.
- Gas: callback batch size, proxy `_extraGas` / `_maxChargeGas`, ladder cost (G3, G4).
- `DelegateSet` event frequency on the testnet endpoints (G1).

## 4. Next steps

| # | Task | Owner | Status | Done when |
|---|---|---|---|---|
| 3 | Fund testnet wallets: Base Sepolia and Ethereum Sepolia ETH, USDC (Circle faucet), lREACT | Aga (Razaqi can fund his own deployer) | Not done | Balances confirmed with `cast balance` |
| 4 | **G1:** event → `react()` on Lasna → callback to a dummy on Base Sepolia, plus dynamic subscribe and `Progress` loop | Aga (Razaqi reviews) | Not started | `getCallbacks(txHash)` shows the callback; tx hashes in `docs/gates.md` |
| 5 | **G2:** deploy and wire `DemoOFT` on Base Sepolia and Ethereum Sepolia, send in both directions | Razaqi deploys and wires, Aga sends | Scripts ready, waits for wallets | Both directions executed; tx hashes in `docs/gates.md` |
| 6 | **G6:** create and seed the DemoOFT/USDC pool on Base Sepolia, swap | Razaqi | Scripts ready, waits for wallets | Swap works; `Swap` event format noted |
| 7 | Dashboard skeleton with wallet connect and network guard | Bayu | In review (`feat/dashboard-skeleton`, 27 Nov): `/dashboard` with wallet connect, testnet guard, Health panel (`debt`/`reserves`/balance from `deployments/`), G1 loop panel from on-chain receipts, DVN read helper (no screen yet). Open: meaning of `reserves()`, 1-of-N DVN rule | Runs locally, testnet only |
| 8 | Branding draft, video outline, judge guide outline | Raka | Project renamed to nothief; drafts not in repo yet | Drafts in `docs/` |
| 9 | `AlarmReactive` | Aga | Not started; needs the decisions in §5 | Compiles, tested, reviewed by Razaqi |
| 10 | `AlarmExecutor` (ladder, registration, callbacks, invariant tests) | Razaqi | Not started; needs the decisions in §5 | All five invariants in `PRD.md` §8.2 tested |

**Stop rule:** if G2 fails in both directions, stop and tell the team. The fallback is the Backstop idea
(`PRD.md` §16). If it works in only one direction, re-evaluate the same day.

## 5. Open decisions

Team decisions (`PRD.md` §18). Item 1 is partly answered (ESC with Ethereum Sepolia: no); item 10 is closed (mainnet
not required).
- Approval policy at registration (B5). Default: user choice, preset to "balance at registration". Blocks `register`.
- S2 subscription expiry. Default: unsubscribe on `ExitCompleted`.
- Which file is the single living doc (`PRD.md` or the research log). Until decided, update `PRD.md` and this file.
- Questions to organizers still open: self-seeded pool, team size, judging window, deadline time zone, and the
  license of `reactive-lib-omni` (its files are `UNLICENSED`).

Interface decisions between Aga and Razaqi (block `AlarmReactive` and `AlarmExecutor`):
- `Baseline` subscription: proposed dynamic per registered chain-X token (topic1), unsubscribed after the first
  baseline, so spam `report()` calls cannot drain lREACT.
- Baseline rule: accept `Baseline` only when no baseline exists; a different value for an existing baseline is an
  alarm, never an overwrite.
- `refPrice` unit: `ExitMath` uses stablecoin units per token unit, scaled by 1e36.
- Callback shape: proposed as in `PRD.md` §8.2 (`onAlarm`, `onConfirm`, first argument `address(0)`).

`AlarmExecutor` behavior, Razaqi to decide and then write into `PRD.md` §8.2:
- Exit ladder: is step 2 "50%" of the original amount or of what remains; is "the rest at 50%" a third step after a
  successful step 2 or a retry after a failure; is the first 20% the user's `slippageBps` or fixed; in "Any price"
  mode, is `minOut` 0 or still bounded by the floor price.
- Floor price of zero: with a stale or zero reference price and `floorPrice = 0`, `ExitMath` gives `minOut = 0`
  (sell at any price). Proposed: `register` rejects `floorPrice = 0` unless the failure mode is "Any price", and the
  executor does not sell when the chosen price is zero outside that mode.

Repo hygiene:
- Branch protection on `main` (require one review): not enabled. Razaqi.
- Repo description and topics on GitHub are empty. Raka (pitch wording), Razaqi applies.
- CI does not run `forge fmt --check`, and the fork test is always skipped in CI (no RPC URL). Aga (CI owner).
