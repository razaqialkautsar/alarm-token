# Gate results

Gates G1–G6 are defined in `PRD.md` §14. Record each result here with tx hashes and the chain of every tx. A unit
test is not evidence of on-chain behavior.

| Gate | Result | Date | Evidence |
|---|---|---|---|
| G1 | **Partly passed.** Basic loop and keeperless `Progress` loop work on-chain. (i) dynamic subscribe, (iii) `Baseline` events, and (iv) `DelegateSet` rate not run yet | 26 Nov 2026 | [G1 below](#g1) |
| G2 | No data yet | | |
| G3 | No data yet | | |
| G4 | No data yet. First data point from G1: proxy overhead, see [G1 findings](#findings) | | |
| G5 | No data yet | | |
| G6 | No data yet | | |

All transactions below are testnet drills played by the team (Aga). Deployer: `0x0BbF1c9aEB3930dEb3B0a58501595aBC750c160C`.

## G1

### Contracts

| Contract | Chain | Address | Deploy tx |
|---|---|---|---|
| `G1Reactive` (callback gas limit 300,000) | Reactive Lasna (5318007) | `0xb5d279B63f40c3E0e24B53F058564658CFd90414` | see `contracts/broadcast/DeployG1Reactive.s.sol/5318007/run-latest.json` |
| `G1Receiver` | Base Sepolia (84532) | `0xb5d279B63f40c3E0e24B53F058564658CFd90414` | see `contracts/broadcast/DeployG1Receiver.s.sol/84532/run-latest.json` |
| `BaselineReporter` | Ethereum Sepolia (11155111) | `0xa8d533CC18c07663c385b7FBbe64D82b86D7d7AD` | `0xb1c143f57361e966a7dda3c9b4e40a92c1114225f9fe09ef8de2de431389b411` |

The two G1 contracts share an address only because the deployer's nonce was the same (2) on both chains.

`configure` on Lasna: `0x6e467e3d38037d45606f4219a1ad03f1a5168fe129a7a75ee6e916dc816b9ac3`.

### Run 2: basic loop and `Progress` loop (passed)

`ping(3)` on Base Sepolia. Each later round was triggered only by the `Progress` event of the previous callback. No
script or bot sent anything after the ping.

| Step | Chain | Tx | Block | Block timestamp (UTC) |
|---|---|---|---|---|
| `Ping(3)` (origin) | Base Sepolia | `0x7e2571adf2638b371b75016eae27e2790a57c1cea26c6e1c98160075a0ebdc03` | 63808727 | 1795683614 (09:00:14) |
| reactive tx, round 3 | Lasna | `0x69142fa0d52fc8745951c2ba021c768effa302055c754588823fff59635b2a67` | 9285198 | 1795683613 |
| callback `onRound(3)` → `Progress(2)` | Base Sepolia | `0x771bf2c27ad99bdc7cce61fd67ffc850809ef31dcbca31a5aafc2b369b0dd392` | 63808736 | 1795683616 |
| reactive tx, round 2 | Lasna | `0x7f38f484c71ac9d430b27f3302c7a7e3d627f3824beeaeba36c640c9d9cab79e` | 9285199 | 1795683614 |
| callback `onRound(2)` → `Progress(1)` | Base Sepolia | `0x807e41331509ee94af4170fc1070fa270ce4cf7b5d87ee869be4b89bb744b12a` | 63808739 | 1795683616 |
| reactive tx, round 1 | Lasna | `0x83c3f7f0de2edfd07709cb4593b254108eb56abf194e5ce918aed75c4cbcde37` | 9285200 | 1795683616 |
| callback `onRound(1)` (last) | Base Sepolia | `0xb953f95bf0a43aa01f931a601afd823d5e4a370774179b3bdff0c209c71a5669` | 63808744 | 1795683617 |

Each reactive tx emitted `CallbackRequested` with the origin tx hash shown in the row above it. After the run,
`roundsReceived()` = 3, and `debt()` = 0 for both contracts.

**Timing (one run, n = 1; not a latency report).** On Base Sepolia, the origin `Ping` and the first callback are 2 s
apart, and the third callback is 3 s after the origin. Both chains report whole-second timestamps, and the Lasna
block that handled the ping is stamped 1 s *before* the origin block, so the clocks of the two chains are not aligned
to the second. Only the Base-to-Base differences are used. The G5 latency report needs more runs (p50, p95, n).

### Run 1: callback ran out of gas (failed, fixed in run 2)

Same setup with a callback gas limit of 200,000 (`G1Reactive` `0xE6557F67970aB4D984726D410aD7F2cdb7b7ef56` on
Lasna, `G1Receiver` at the same address on Base Sepolia).

- `ping(3)` on Base Sepolia: `0xdcd9963fe7d0b451266386b42f1a4e171e1c2de4376ed30c1ee4c47974c37fe0`.
- `react()` ran on Lasna and requested the callback: `0xdf70fc02c6ad2d731ce7177e390c7ccd8adc0769d0f0ffc1d6865a1cee7cce53`.
- The callback proxy delivered it on Base Sepolia: `0x120b83b9f9030661c0a9a711a54e68e76fdbb63f0ae18aaf38dc5c2676f4468a`.
  The trace (`cast run`) shows `onRound` received **24,190 gas** and hit `OutOfGas` after `RoundReceived`. The proxy
  emitted `CallbackFailure(address,bytes)` and still charged the receiver 728,230,800,000 wei through `pay()`.
- `getCallbacks(reactiveTxHash)` on the system contract returned `[]` both before and after the delivery.

These contracts have no withdraw function, so about 0.99 lREACT and 0.0002 ETH stay in them. Run 2 contracts have an
owner-only `withdraw`.

### Findings

1. **The requested callback gas limit is the gas limit of the whole proxy transaction, not the gas the callback
   receives** [Fact: run 1 trace]. With 200,000 requested, the proxy tx had `gasLimit` 200,000 and forwarded 24,190 gas
   to the callback, so about 176,000 went to proxy overhead and the post-call payment reserve. The first `onRound`
   needs about 37,300 gas (unit test, cold storage). `AlarmExecutor`'s callback limit (G4) must add this overhead on top
   of the swap cost. Whether the overhead is fixed or scales with the limit is not measured yet.
2. **A failed callback is still charged.** The proxy catches the failure, emits `CallbackFailure`, and calls `pay()` on
   the receiver [Fact: run 1 trace]. This matches the docs and the "no revert per user" rule for the executor.
3. **Cost of one small callback on Base Sepolia:** 728,230,800,000 wei (about 0.00000073 ETH) in run 1. Receiver
   balance went from 100,000,000,000,000 to 98,078,715,193,840 wei over the three run-2 callbacks (about 0.00000064 ETH
   each) [Fact: balance reads].
4. **`getCallbacks(reactiveTxHash)` returned an empty array even after the callback was delivered** in run 1. Do not
   use it as the only delivery check. The receiver's own events and the proxy's `CallbackFailure` event are reliable.
5. **Ethereum Sepolia contract creation costs much more gas than `forge` 1.7.1 simulates.** For `BaselineReporter`,
   the Ethereum Sepolia node estimated 1,783,290 gas while Base Sepolia estimated 279,507 for the same bytecode. Two
   broadcasts with forge's own gas limit (358,992) ran out of gas: `0xc13893dd30c360f5de7f5fae494217dce824bd34b2c24d6e2188aa5e46f40caa`
   and `0x2697dba9385ccfc4710d75fafd2ceb3339fc6d7f1610eb211b58f8bd866e9f76`. Deploying with `--skip-simulation`, so that
   the node estimates the gas, worked. **Use `--skip-simulation` for deploys on Ethereum Sepolia** (this affects
   `DeployDemoOFT` for G2). Why Sepolia charges more is not verified.
6. The public Ethereum Sepolia RPC `https://ethereum-sepolia-rpc.publicnode.com` often answered `block not found`
   during `forge script` simulation. Retrying a simulation is safe; retrying a broadcast is not (check `cast nonce`
   first).

### Still to do for G1

- (i) + (iii): `watch(tokenX)` on Base Sepolia, then `BaselineReporter.report(tokenX, 40245)` on Ethereum Sepolia, and
  check `G1Receiver.baselines(tokenX)`. Needs an OApp token on Ethereum Sepolia (DemoOFT from G2).
- (iv): count `DelegateSet` logs on both testnet endpoints over a fixed block range with `cast logs`.
