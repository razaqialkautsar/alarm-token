# scripts

Off-chain tooling (`PRD.md` §10). Owner: Aga.

- Drill runner, latency tool, funding helpers, gate experiments.
- **Not part of the protection loop.** Protection must keep working if every script stops (guardrail V6).
- Read addresses from `deployments/` and keys from `.env`. Every script that sends a tx prints the tx hash and the
  chain.

Foundry scripts (`Deploy*.s.sol`, `Drill*.s.sol`, `Gate*.s.sol`) live in `contracts/script/`.

Nothing here yet.
