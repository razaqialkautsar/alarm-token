# deployments

Deployed contract addresses, one `<chain>.json` file per chain, written by the deploy scripts (`PRD.md` §10, §12).

Testnet only: Reactive Lasna (5318007), Base Sepolia (84532), and chain X (Ethereum Sepolia 11155111 or Unichain
Sepolia 1301). Never add mainnet addresses.

## Files and schema

One file per chain: `base-sepolia.json`, `ethereum-sepolia.json`, `unichain-sepolia.json`, `reactive-lasna.json`.

```json
{
  "chainId": 84532,
  "contracts": {
    "DemoOFT": { "address": "0x..." },
    "UniswapV3Pool_DemoOFT_USDC_3000": { "address": "0x..." }
  }
}
```

- Keys under `contracts` are contract names. A pool key ends with its fee tier, because each tier is a separate pool.
- Deploy scripts write these files through `contracts/script/DeploymentRecorder.sol`, **only with `--broadcast`**. Dry
  runs and tests do not write. Redeploying overwrites the entry; the history stays in `contracts/broadcast/`, which
  also holds the tx hashes.
- The file is written while the script simulates, before the transaction is mined. After a broadcast, confirm the
  address with `cast code <address> --rpc-url <rpc>` before relying on it.
- Readers (scripts, dashboard) read `contracts.<Name>.address`.

No deployments yet.
