# CONTEXT.md: Current status and next steps

Last updated: 23 Nov 2026. Update this file whenever the status changes (gates passed, contracts deployed, decisions
changed).

Read `PRD.md` and `CLAUDE.md` before this file.

---

## 1. Where the project stands

- **Design: final.** Research and brainstorming ran from 18 to 23 Nov. All design decisions are in `PRD.md`. The full
  reasoning (Indonesian) is in `D:\Project\HACKATHON LAGI\alarm-token-final.md`.
- **Code: repo initialized** at `github.com/razaqialkautsar/alarm-token` with docs, license, and the folder layout
  from `PRD.md` §12. The contracts scaffold (tasks 1 and 2) is in progress on branch `feat/scaffold-contracts`.
- **Gates: not run.** G1, G2, G4 have not started. G3, G5, G6 are partly done from research only (see §2).
- **Deadline:** submit on **4 Dec 2026** (event ends 5 Dec, time zone not published). About 11 days left.
- **Track:** not chosen yet. Decided after G5 (`PRD.md` §4.4). Default is Set It and Forget It if chain X ends up
  being Ethereum Sepolia.

## 2. Already verified during research (do not redo, but re-check on our own deployments)

| Item | Result | Source |
|---|---|---|
| `PeerSet` topic0 | `0x238399d4…b98b`, EID and peer in `data` | GAIN mainnet logs, `cast keccak` |
| `DelegateSet` | `DelegateSet(address sender, address delegate)`, no indexed params, emitted by EndpointV2 | LayerZero V2 source |
| `OFTReceived` | Emitted on every inbound OFT message, carries `srcEid` | LayerZero V2 source, Sandbox logs |
| `endpoint.delegates(oapp)`, `peers(eid)` | Both public getters | LayerZero V2 source |
| DVN config read | `getReceiveLibrary` then `getUlnConfig` | LayerZero V2 source (call not yet tested) |
| GriffinAI timeline | `setPeer` → fake mint: 1,344 s | BSC on-chain data |
| The Sandbox timeline | `DelegateSet` → first fake mint: 24 s, no `setPeer` | Base mainnet on-chain data |
| Unichain Sepolia | DEPRECATED in LayerZero metadata, all four DVNs deprecated | LayerZero `/v1/metadata/deployments` |
| Uniswap on Base Sepolia | v4 PoolManager and v3 Factory addresses have code | Uniswap docs + RPC |
| USDC on Base Sepolia | `0x036CbD53842c5426634e7929541eC2318f3dCF7e`, `symbol()` = USDC | Search limited to Circle docs + RPC |
| Reactive API | Use Omni API from `reactive-lib-omni`. The official demo repo is Legacy | Reactive docs and repos |

Addresses and full details: `PRD.md` §7.1, §7.4, §8.5, §20.

## 3. Not known yet (must be resolved by doing, not guessing)

- How to install `reactive-lib-omni` and set up the `@reactive/` remapping. Not documented. Try the Reactive MCP
  `get_rc_template`, or add the repo as a git submodule.
- Exact LayerZero V2 OFT package and version.
- One compiler version that works with both LayerZero (`^0.8.20`) and `reactive-lib-omni` (`^0.8.29`).
- Whether OFT messages work both ways between Base Sepolia and Unichain Sepolia, or Ethereum Sepolia (G2).
- Uniswap v3 or v4, and the `Swap` event format (G6).
- Gas: callback batch size, proxy `_extraGas` / `_maxChargeGas`, ladder cost (G3, G4).
- `DelegateSet` event frequency on the testnet endpoints (G1).

## 4. Next steps (Phase "Setup and gates", 23–24 Nov)

| # | Task | Owner | Done when |
|---|---|---|---|
| 1 | Scaffold the repo as in `PRD.md` §12: Foundry project in `contracts/`, `.gitignore`, `.env.example`, license. Razaqi writes the first minimal CI workflow (`forge build` + `forge test`); CI is owned by Aga from then on (`PRD.md` §15) | Razaqi (scaffold, first CI), Aga (CI afterwards) | `forge build` passes in CI |
| 2 | Resolve dependencies and the compiler pin (§3 above) | Razaqi | A minimal `AbstractReactive` and an OFT both compile |
| 3 | Fund testnet wallets: Base Sepolia, Ethereum Sepolia, Unichain Sepolia ETH; lREACT from the faucet | Aga | Balances confirmed with `cast balance` |
| 4 | **G1:** event → `react()` on Lasna → callback to a dummy on Base Sepolia, plus dynamic subscribe and `Progress` loop | Aga (Razaqi reviews) | `getCallbacks(txHash)` shows the callback; tx hashes in `docs/gates.md` |
| 5 | **G2:** deploy `DemoOFT` on Base Sepolia and chain X, send in **both directions** | Razaqi deploys, Aga runs | Both directions executed; tx hashes in `docs/gates.md` |
| 6 | **G6:** create and seed the DemoOFT/USDC pool on Base Sepolia | Razaqi | Swap works; `Swap` event format noted |
| 7 | Dashboard skeleton with wallet connect and network guard | Bayu | Runs locally, testnet only |
| 8 | Branding draft, video outline, judge guide outline | Raka | Drafts in `docs/` |

**Stop rule:** if G2 fails in both directions by end of 24 Nov, stop and tell the team. The fallback is the Backstop
idea (`PRD.md` §16). If it works in only one direction, re-evaluate the same day.

## 5. Open decisions (do not decide alone)

See `PRD.md` §18. The ones that block code soon:
- Approval policy at registration (B5). Default: user choice, preset to "balance at registration".
- S2 subscription expiry. Default: unsubscribe on `ExitCompleted`.
- Which file is the single living doc (`PRD.md` or the research log). Until decided, update `PRD.md` and this file.
