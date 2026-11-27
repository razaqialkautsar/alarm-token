import type { Address } from "viem";
import { baseSepolia, reactiveTestnet, sepolia } from "viem/chains";

// Testnet only (CLAUDE.md §2.4). No mainnet chain is ever added here: the wallet guard treats any chain outside this
// list as the wrong network.
export const APP_CHAINS = [baseSepolia, sepolia, reactiveTestnet] as const;

export type AppChainId = (typeof APP_CHAINS)[number]["id"];

export { baseSepolia, reactiveTestnet as lasna, sepolia as ethereumSepolia };

/** Public, keyless RPCs. Same URLs as `.env.example`; `cast chain-id` returned 84532 and 5318007 on 27 Nov 2026. */
export const RPC_URLS = {
  [baseSepolia.id]: "https://sepolia.base.org",
  [reactiveTestnet.id]: "https://lasna-rpc.rnk.dev/",
  // Ethereum Sepolia: viem's default public RPC. Not read by any screen yet.
  [sepolia.id]: undefined,
} as const satisfies Record<AppChainId, string | undefined>;

/** Reactive system contract on Lasna. Holds `debt()` for reactive contracts [Fact: Reactive docs, PRD.md §7.1]. */
export const REACTIVE_SYSTEM_CONTRACT: Address = "0x8888888888888888888888888888888888888888";

/**
 * Reactive callback proxy per destination chain. Delivers callbacks and holds `debt()` for callback contracts.
 * [Fact: Reactive docs `/origins-and-destinations`, PRD.md §7.1]
 */
export const CALLBACK_PROXY = {
  [baseSepolia.id]: "0x476F44b11F5C942c58f4c8E3d0300E5710743585",
  [sepolia.id]: "0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4",
} as const satisfies Record<number, Address>;

/**
 * LayerZero EndpointV2 on Base Sepolia and Ethereum Sepolia (same address on both).
 * [Fact: LayerZero `/v1/metadata/deployments` and `eid()` read on-chain, 25 Nov 2026, PRD.md §7.1]
 */
export const LZ_ENDPOINT_V2: Address = "0x6EDCE65403992e310A62460808c4b910D972f10f";

/** LayerZero endpoint IDs (PRD.md §7.1). */
export const LZ_EID = {
  [baseSepolia.id]: 40245,
  [sepolia.id]: 40161,
} as const satisfies Record<number, number>;

export function chainById(chainId: number) {
  return APP_CHAINS.find((chain) => chain.id === chainId);
}
