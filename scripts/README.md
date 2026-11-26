# scripts

Off-chain tooling (`PRD.md` §10). Owner: Aga.

- Drill runner, latency tool, funding helpers, gate experiments.
- **Not part of the protection loop.** Protection must keep working if every script stops (guardrail V6).
- Read addresses from `deployments/` and keys from `.env`. Every script that sends a tx prints the tx hash and the
  chain.

Foundry scripts (`Deploy*.s.sol`, `Drill*.s.sol`, `Gate*.s.sol`) live in `contracts/script/`.

## `wallet.sh`: testnet wallet setup

Run it in your own terminal from the repo root:

```sh
bash scripts/wallet.sh            # guided setup: .env, testnet-only key, RPC check, balances, faucet steps
bash scripts/wallet.sh balance    # balances on Ethereum Sepolia, Base Sepolia, and Reactive Lasna
bash scripts/wallet.sh lreact     # swap testnet ETH for lREACT through the Reactive faucet (asks before sending)
```

The key is written to `.env` (git-ignored) and never printed. Every RPC is checked against its testnet chain ID.
`lreact` refuses amounts above 5 ETH, because the faucet loses anything above that per tx.
