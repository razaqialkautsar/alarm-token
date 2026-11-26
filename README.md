# nothief

Cross-chain exit protection for holders of LayerZero V2 OFT tokens, built for the Reactive Omni Buildathon.

> **Status: work in progress.** Nothing is deployed yet. The spec is in [`PRD.md`](PRD.md). The project narrative,
> evidence, and drill guide will be added as they are produced.

## Repository layout

| Path | Content |
|---|---|
| `contracts/` | Foundry project (Solidity): reactive contract, executor, reporter, drill contracts |
| `app/` | Dashboard (Next.js). Frontend only, no backend |
| `scripts/` | Off-chain tooling: drill runner, latency tool, funding helpers. Not part of the protection loop |
| `deployments/` | Deployed addresses per chain |
| `docs/` | Gate results, tx-hash evidence, architecture, drill guide |
| `.github/workflows/ci.yml` | CI: `forge build` and `forge test` |
| `PRD.md` | Product and technical spec |
| `CLAUDE.md` | Working rules for the team and AI agents |
| `CONTEXT.md` | Current status and next steps |

## Build and test

Prerequisites: [Foundry](https://getfoundry.sh) v1.7.1 (the version CI uses), Node.js 24 with npm, and git.

```sh
git clone --recurse-submodules https://github.com/razaqialkautsar/alarm-token.git
cd alarm-token/contracts
npm ci          # REQUIRED before forge build: LayerZero and OpenZeppelin sources come from npm
forge build
forge test
```

If you cloned without `--recurse-submodules`, run `git submodule update --init --recursive` first.

`forge build` fails with missing `@layerzerolabs/...` or `@openzeppelin/...` imports if `npm ci` has not been run.

## Deploy `DemoOFT` (testnet drill token)

`contracts/script/DeployDemoOFT.s.sol` deploys one `DemoOFT` on the chain behind the RPC URL. It only accepts the
testnet chain IDs Base Sepolia (84532), Ethereum Sepolia (11155111), and Unichain Sepolia (1301), and it checks that the
LayerZero endpoint reports the expected EID before deploying. The deployer becomes owner and LayerZero delegate.

```sh
cd contracts
source ../.env   # PRIVATE_KEY must be a dedicated testnet-only key
# Dry run (no transaction is sent):
forge script script/DeployDemoOFT.s.sol --rpc-url $ETH_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
# Send it, once per chain:
forge script script/DeployDemoOFT.s.sol --rpc-url $ETH_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

Optional environment variables: `DEMO_OFT_NAME`, `DEMO_OFT_SYMBOL`, `DEMO_OFT_INITIAL_SUPPLY` (whole tokens, default
1,000,000). Record the printed address in `deployments/` and the tx hash in `docs/gates.md`.

Then wire the peers, once per chain, each time pointing at the token on the other chain
(`contracts/script/WireDemoOFT.s.sol`). The signer must own the local token. It skips the call if the peer is already
set, because `PeerSet` is emitted on every `setPeer`, even with an unchanged value.

```sh
# On Base Sepolia, pointing at the Ethereum Sepolia token (EID 40161). Swap the values for the other chain.
LOCAL_OFT=0x... REMOTE_EID=40161 REMOTE_OFT=0x... \
  forge script script/WireDemoOFT.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

Then send tokens across (`contracts/script/SendDemoOFT.s.sol`), one direction per run. Run it again on the other chain
for the opposite direction (gate G2). The signer pays the LayerZero fee in native token and must hold the tokens. The
script prints the GUID; track it on LayerZero Scan (testnet) and record the source and destination tx hashes in
`docs/gates.md`. Optional: `TO` (recipient, default the signer), `LZ_RECEIVE_GAS` (default 200000).

```sh
LOCAL_OFT=0x... DST_EID=40161 AMOUNT_TOKENS=100 \
  forge script script/SendDemoOFT.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## G6 pool: DemoOFT/USDC on Uniswap v3 (Base Sepolia)

Two scripts create and test the pool for gate G6. Both accept Base Sepolia only. Uniswap v3 is the working choice; v4 was
not evaluated (`PRD.md` section 18, item 4 stays open until G6 is recorded on-chain).

1. Get testnet USDC at the Circle faucet for the deployer wallet.
2. `contracts/script/CreateDemoPool.s.sol` creates the pool and seeds full-range liquidity. The ratio of the two
   amounts sets the starting price. Required env: `DEMO_OFT`, `DEMO_TOKENS`, `USDC_TOKENS` (whole tokens). Optional:
   `POOL_FEE` (default 3000).
3. `contracts/script/SwapDemoPool.s.sol` sells DemoOFT for USDC. Use its tx hash to read the pool `Swap` event and note
   the format in `docs/gates.md`. Required env: `DEMO_OFT`, `SELL_TOKENS`.

```sh
cd contracts
DEMO_OFT=0x... DEMO_TOKENS=100000 USDC_TOKENS=10 \
  forge script script/CreateDemoPool.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
DEMO_OFT=0x... SELL_TOKENS=1000 \
  forge script script/SwapDemoPool.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

`test/fork/DemoPool.fork.t.sol` rehearses both scripts on a Base Sepolia fork. It runs only when `BASE_SEPOLIA_RPC_URL`
is set, so CI skips it. A fork run is a rehearsal, not evidence: gate results need real tx hashes.

## Dependencies

All versions are pinned exactly. npm versions are locked in `contracts/package-lock.json` (`contracts/.npmrc` sets
`save-exact` and `legacy-peer-deps`, so only the packages listed below are installed). Submodule commits are pinned in
git and in `contracts/foundry.lock`.

| Dependency | Version | Source | License (as declared by the package) | Used for |
|---|---|---|---|---|
| Solidity compiler | 0.8.30 | `foundry.toml` | GPL-3.0 (compiler, not linked) | All contracts |
| `forge-std` | v1.17.0 (`f3dae6e`) | git submodule | Apache-2.0 OR MIT | Tests and scripts |
| `reactive-lib-omni` | `3ade0dc` (tag v0.1.0) | git submodule | **None.** Files are `SPDX-License-Identifier: UNLICENSED`, see below | Reactive contract and callback base contracts |
| `@layerzerolabs/oft-evm` | 4.0.1 | npm | MIT | OFT |
| `@layerzerolabs/oapp-evm` | 0.4.1 | npm | MIT | OApp base |
| `@layerzerolabs/lz-evm-protocol-v2` | 3.0.168 | npm | LZBL-1.2 (package), mixed per file | Endpoint interfaces and libraries |
| `@layerzerolabs/lz-evm-messagelib-v2` | 3.0.168 | npm | LZBL-1.2 (package), mixed per file | Message library types (tests) |
| `@openzeppelin/contracts` | 5.6.1 | npm | MIT | ERC20, Ownable |
| `solidity-bytes-utils` | 0.8.4 | npm | MIT | LayerZero dependency |
| `@layerzerolabs/test-devtools-evm-foundry` (dev) | 8.0.1 | npm | MIT (package), mixed per file | `TestHelperOz5` with mocked endpoints for tests |
| `@layerzerolabs/lz-evm-v1-0.7` (dev) | 3.0.168 | npm | BUSL-1.1 | Interface imported by the test helper's DVN mock |

LayerZero documents the npm package `@layerzerolabs/oft-evm`
([OFT quickstart](https://docs.layerzero.network/v2/developers/evm/oft/quickstart)) and the Foundry test helper
`@layerzerolabs/test-devtools-evm-foundry` for a hybrid Foundry and npm setup
([TestHelper](https://docs.layerzero.network/v2/developers/evm/tooling/test-helper)). The quickstart's own Foundry
example uses git submodules instead; we use npm so versions are pinned by one lockfile.

### Licensing notes

This repository's own code is MIT licensed (see [`LICENSE`](LICENSE)). Third-party code keeps its own license:

- **`reactive-lib-omni` has no license.** The repository has no LICENSE file and every source file is marked
  `SPDX-License-Identifier: UNLICENSED` (checked at commit `3ade0dc`). We do not copy it into this repository; it is
  referenced as a git submodule and is not covered by our MIT license. It is the official Reactive Network library
  for the Omni API.
- **LayerZero protocol code uses LZBL-1.2 and BUSL-1.1 in some files.** Compiling `DemoOFT` pulls in two LZBL-1.2
  files from `lz-evm-protocol-v2` (`libs/AddressCast.sol`, `messagelib/libs/PacketV1Codec.sol`), imported by the
  official `OFTCore`. All other sources in `DemoOFT` are MIT. The BUSL-1.1 package `lz-evm-v1-0.7` is used only by
  the test helper. We do not modify or redistribute these files; they are installed from npm.
- `npm audit` reports advisories in JavaScript packages pulled in by `@layerzerolabs/oapp-evm` (`ethers` v5 and
  `ws`). Foundry only reads the `.sol` files; that JavaScript is never executed by the build or tests.

## Compiler and EVM target

`contracts/foundry.toml` pins `solc_version = "0.8.30"` and `evm_version = "prague"` for every contract. 0.8.30
satisfies LayerZero V2 (`pragma ^0.8.20`) and `reactive-lib-omni` (`pragma ^0.8.29`); both compile and the tests pass.

Neither the Reactive docs nor the Base docs name a Solidity `evm_version`. We checked the chains directly on
23 Nov 2026 by running small `eth_call` creation-code probes against each public RPC:

| Probe | Reactive Lasna (5318007) | Base Sepolia (84532) | Ethereum Sepolia (11155111) |
|---|---|---|---|
| `PUSH0` (Shanghai) | ok | ok | ok |
| `TSTORE`/`TLOAD`, `MCOPY` (Cancun) | ok | ok | ok |
| `BLOBBASEFEE` (Cancun) | **RPC error** (`method handler crashed`) | ok | ok |
| `CLZ` (Osaka) | ok | ok | ok |
| BLS12-381 precompile `0x0b` (Prague) | present | present | present |
| EIP-2935 history contract (Prague) | **no code** | present | present |
| Blob fields in block header | **absent** | present | present |

Base docs state that Isthmus, which "incorporates Ethereum Pectra EIPs", is active on Base Sepolia since
17 Apr 2025 ([Base upgrades](https://docs.base.org/upgrades/overview)). solc 0.8.30 also accepts `osaka`, but we
need no Osaka features, so we stay on `prague` as the more conservative target.

Conclusion: one `prague` profile works for all chains. **On Lasna, do not use `block.blobbasefee` or `blobhash`, and
do not rely on EIP-2935 block-hash history.** Solidity emits these only when code uses them. These are RPC probes,
not deployed-contract proofs; the first Lasna deployment (gate G1) confirms them.

## License

MIT, see [`LICENSE`](LICENSE).
