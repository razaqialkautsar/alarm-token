# Alarm Token

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
| `PRD.md` | Product and technical spec |
| `CLAUDE.md` | Working rules for the team and AI agents |
| `CONTEXT.md` | Current status and next steps |

## License

MIT, see [`LICENSE`](LICENSE).
