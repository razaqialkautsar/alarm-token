# CLAUDE.md: Working rules for Alarm Token

These rules apply to every person and every AI agent working on this project. If a rule here conflicts with a
request, stop and ask.

## 0. Session start (do this first, every session)

1. Read `PRD.md` in full. It is the spec for everything you build here.
2. Read the rest of this file.
3. Read `CONTEXT.md`: current project status and next steps.
4. Read `ME.md` if it exists. It is personal and git-ignored, and tells you which team member you are working with
   and what they own. If it is missing, ask who you are working with before doing any work.
5. Before starting a task, confirm which `PRD.md` section it belongs to and that it is inside the person's role
   (`PRD.md` §15). If it belongs to someone else's area, say so and ask.

---

## 1. What this project is

Alarm Token protects holders of LayerZero V2 OFT tokens. A reactive contract on Reactive Network (Lasna testnet)
watches for bridge-trust hijacks (peer change, delegate change). A callback on Base Sepolia swaps registered holders'
tokens to USDC and sends the proceeds to their own wallets. No bot, no server, no issuer permission.

Built for the Reactive Omni Buildathon (5 Nov to 5 Dec 2026). We submit on **4 Dec**.

| File | Role |
|---|---|
| `PRD.md` | Source of truth for what to build: scope, architecture, specs, roles, timeline |
| `CLAUDE.md` | This file: how we work |
| `CONTEXT.md` | Current status, what is verified, and next steps |
| `ME.md` (git-ignored, optional) | Which team member is using this machine and their role |
| `D:\Project\HACKATHON LAGI\alarm-token-final.md` | Decision history and reasoning (Indonesian, outside this repo) |
| `D:\Project\HACKATHON LAGI\reactive-omni-notes.md` | Hackathon rules and Reactive docs notes with sources (Indonesian, outside this repo) |

---

## 2. Ground rules (non-negotiable)

### 2.1 Ask, do not assume

- If something is unclear or a decision is missing, **ask the team before acting**. Do not invent requirements,
  addresses, numbers, or decisions.
- Never change a decision recorded in `PRD.md` on your own. Propose the change, explain the trade-off, and wait for
  approval.
- When a safe default exists and the task can continue, state the default clearly and flag it.

### 2.2 No unverified claims

- Every factual claim in docs, README, comments, UI copy, and the video must be traceable to a source.
- Use the labels from `PRD.md` §0.1 in internal docs: **[Fact: source]**, **[Secondary]**, **[Team claim]**,
  **[Inference]**, **[Assumption]**, **[Opinion]**.
- Judge-facing material (README, video, DoraHacks page) may only claim protection for patterns that are covered
  **and** verified: GriffinAI (peer change) and The Sandbox (delegate change). Other incidents are context only.
- Never present a measurement we did not take. Latency numbers come only from our own timestamped runs (G5).
- When you are wrong, say so plainly and correct the record.

### 2.3 No mock data, no mock features

- Every number on the dashboard comes from a real on-chain read or a real tx.
- Drills are real transactions on testnet. Always label them as drills, played by the team (or the judge).
- Empty states say "no data yet". No placeholders that look like real data.

### 2.4 Hackathon compliance

- All project code is written during the event (from 5 Nov 2026). Older code is allowed **only as a dependency**.
- The repo is public and open source, with a license.
- **Testnet only:** Reactive Lasna (5318007), Base Sepolia (84532), and chain X (Unichain Sepolia 1301 or Ethereum
  Sepolia 11155111). **Never mix mainnet and testnet.** No mainnet RPCs, keys, or addresses in configs.
- Measure time on Base Sepolia with **timestamps, not block counts**.
- The submission needs contract addresses, full-loop tx hashes (origin event → reactive tx → callback), and a video
  under 3 minutes. Keep `docs/tx-hashes.md` up to date as evidence is produced.

---

## 3. Architecture guardrails

Never break these (`PRD.md` §5):

| # | Guardrail |
|---|---|
| V1 | Exit is a swap to a **stablecoin**, not a token transfer |
| V2 | Automatic. The user does nothing at alarm time |
| V3 | Cross-chain: cause on chain A, action on chain B (scenario a) |
| V4 | No issuer permission or cooperation |
| V5 | Non-custodial: tokens stay in the user's wallet until the exit |
| V6 | **No bot, keeper, or server in the core loop.** Scripts are tooling only |

Executor invariants (each needs a Foundry invariant or fuzz test, `PRD.md` §8.2):
1. Exit proceeds go **only** to the address of the user whose tokens were sold.
2. Exactly one way to move user tokens: swap to the stablecoin with output to that user.
3. Never take more than `min(balance, allowance)` from a user.
4. Callback entry points only accept the callback proxy with the correct reactive sender.
5. A single user's failure never reverts the whole callback.

Never add: an "attack" button that needs the team's owner key on a server, a token with an open `setPeer`, a fee
skimmed from exit proceeds, or any off-chain component the protection depends on.

---

## 4. Reactive Network rules (Omni API)

Source: official docs, summarized in `reactive-omni-notes.md`. The official demo repo uses the **Legacy** API. Do not
copy from it.

- Use `reactive-lib-omni`: `AbstractReactive`, `AbstractCallback`, `AbstractPayer`.
- Use `onlySystem` on `react()`, `SYSTEM.subscribe(...)`, and `SYSTEM.requestCallbackV_1_0(...)`.
- **Never use** `vmOnly`, `service.subscribe`, `if (!vm)`, or `emit Callback(...)`.
- System contract: `0x8888888888888888888888888888888888888888`.
- **Callback payload:** the first parameter must be an `address`, filled with `address(0)`. Reactive overwrites it with
  the reactive contract address. Forgetting this is the most common way to break callbacks.
- Callback `gasLimit` must be **≥ 100,000** or the request is dropped. A reactive tx is capped at **900,000** gas.
- **Never revert or `require` inside `react()` to filter logs.** Reverts are charged in full. Ignore non-matching logs.
- Check `log.opCode` (number of topics) before decoding `log.data`. A zero topic does not prove absence.
- `LogRecord` has **no origin timestamp**. Use Lasna `block.timestamp` when you need time inside `react()`.
- Callback receivers use **both** `onlyServiceProvider` and `onlyCallbackSender(reactiveAddress)`. Both constructor
  values are immutable; a wrong value means redeploying.
- Deploy order: reactive contract → callback contract (with proxy + reactive address) → set the recipient in the
  reactive contract through an owner-only setter → fund both.
- **Any debt stops execution silently.** Expose `coverDebt()`. Fund with `depositTo(address)` on the system contract
  or the callback proxy. Never send REACT straight to the system contract (it credits the sender, not the contract).
- Subscriptions: exact matching only, no OR, duplicates still cost gas. `unsubscribe()` silently fails unless all six
  arguments match, so use one internal helper for subscribe and unsubscribe. Subscriptions cannot be read on-chain;
  track them in state.
- Callbacks are charged to the **recipient** in the destination chain's native token.
- The Reactive MCP (`https://mcp.rnk.dev/mcp`) helps with diagnosis and templates. Its generated code can be wrong.
  Read every line that moves funds before it goes on-chain.

## 5. LayerZero rules

- Use the deployment metadata endpoint `/v1/metadata/deployments` for chain and DVN status, not `/metadata/dvns`.
- Unichain Sepolia (EID 40333) is DEPRECATED in LayerZero metadata. Do not assume it works until G2 proves it.
- `PeerSet` is emitted on every `setPeer`, including when the value does not change. Compare against the baseline.
- `DelegateSet(address sender, address delegate)` is emitted by EndpointV2 and has **no indexed params**. Filter
  `sender` inside `react()`.
- Baselines are read on-chain (`peers(eid)`, `endpoint.delegates(oapp)`), never taken from user input.
- Drill tokens are standard OFTs. No backdoors. The attacker contract is clearly labeled drill-only.

---

## 6. Code conventions

### 6.1 General
- **Everything in the repo is in English:** code, comments, commit messages, README, docs, UI copy.
- Keep it simple. No speculative abstractions, no unused code.
- Contract and module names follow `PRD.md` §7.2 and §12.

### 6.2 Solidity (Foundry)
- Pin one exact compiler version that satisfies LayerZero (`^0.8.20`) and `reactive-lib-omni` (`^0.8.29`).
- Use custom errors, NatSpec on every external function, and an event for every state change and every exit result.
- Checks-effects-interactions. Reentrancy protection on anything that moves tokens.
- No magic numbers: name constants (gas limits, basis points, EIDs, chain IDs).
- Addresses come from `deployments/<chain>.json` or constructor arguments. Never hard-code an address you did not
  verify; if you add one, cite its source in a comment.
- `forge fmt` before committing.

### 6.3 Tests
- Unit tests for every function, fuzz tests for amounts and settings, invariant tests for the executor invariants.
- `forge test` must pass in CI before merge.
- Testnet behavior (callbacks, LayerZero delivery, gas) is proven with gate scripts that log tx hashes to
  `docs/gates.md`. A unit test is not evidence of on-chain behavior.

### 6.4 Frontend (Next.js, TypeScript)
- Frontend only. No API routes that hold keys or sign transactions.
- Every displayed number links to its tx or contract read.
- Block the app on the wrong network. No mainnet chains configured.

### 6.5 Scripts
- Scripts are tooling. The protection loop must work if every script stops.
- Scripts read addresses from `deployments/` and keys from `.env`.
- Every script that sends a tx prints the tx hash and the chain.

---

## 7. Security and secrets

- **Never commit private keys, mnemonics, or RPC keys.** `.env` is git-ignored; keep `.env.example` current.
- Use dedicated testnet-only wallets. Never use a wallet that holds mainnet funds.
- The lREACT faucet takes at most 5 ETH per tx. Anything above is lost. Send small amounts.
- Before any deploy, print the chain ID and confirm it is a testnet ID from §2.4.

---

## 8. Git workflow

- `main` is always deployable. Work on branches: `feat/...`, `fix/...`, `test/...`, `docs/...`, `gate/...`.
- Commit messages: Conventional Commits in English (`feat(executor): add exit ladder`).
- Every PR needs one review from another team member. PRs that touch fund-moving code need Razaqi's review.
- Do not push, force-push, or merge for someone else without asking.

---

## 9. Gates and decision changes

- Gates G1–G6 (`PRD.md` §14) come before the full build. Record each result with tx hashes in `docs/gates.md`.
- If a gate fails, stop and report. Do not quietly switch the design. Kill and fallback rules are in `PRD.md` §16.
- When a decision changes, update `PRD.md` in the same PR and say what changed and why.

---

## 10. Rules for AI agents

- Read `PRD.md` and this file first. Re-read the relevant PRD section before touching a component.
- Ask before assuming, especially about addresses, chain IDs, gas numbers, event formats, and team decisions.
- Verify external facts against primary sources (docs, verified contract source, on-chain data) and cite them.
  Search results and summaries are [Secondary] until confirmed.
- Never fabricate tx hashes, addresses, measurements, or incident details.
- Do not expand scope. Stretch items (`PRD.md` §6.2) start only when the team says the MVP is done.
- When reviewing generated code, check fund flows, access control, and revert behavior first.
- Report honestly what was done, what was verified, and what was not.

---

## 11. Definition of done (per task)

- [ ] Matches the behavior in `PRD.md`, with no guardrail broken.
- [ ] Tests added or updated, `forge test` and frontend build pass.
- [ ] On-chain behavior proven on testnet with tx hashes recorded, if the task touches the loop.
- [ ] Docs updated (`README.md`, `docs/`, `deployments/`) where relevant.
- [ ] Reviewed by another team member.
