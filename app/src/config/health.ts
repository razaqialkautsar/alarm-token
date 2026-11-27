import type { Address } from "viem";
import { type AppChainId, CALLBACK_PROXY, REACTIVE_SYSTEM_CONTRACT, baseSepolia, lasna } from "./chains";

/**
 * `debt(address)` is in `IPayable` (reactive-lib-omni), implemented by the system contract and the callback proxy.
 * `reserves(address)` is not in the library's interfaces. It is listed in PRD.md §20.1 [Fact: Reactive docs], and a
 * call on both contracts returned a value on 27 Nov 2026. What it counts is not verified: for `G1Reactive` it returned
 * 0 while the contract itself held 0.46 lREACT. So the panel shows it as a raw read, next to the contract balance.
 */
export const payerAbi = [
  {
    type: "function",
    name: "debt",
    stateMutability: "view",
    inputs: [{ name: "contract_", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "reserves",
    stateMutability: "view",
    inputs: [{ name: "contract_", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

export type HealthTarget = {
  /** Contract name as written in `deployments/<chain>.json`. */
  name: string;
  chainId: AppChainId;
  /** Contract that tracks this contract's debt: the system contract (Lasna) or the callback proxy (destination). */
  payer: Address;
  payerLabel: string;
  /** `gate` contracts are experiments, not part of the protection loop. */
  kind: "protection" | "gate";
};

// A contract in debt stops executing without an error [Fact: Reactive docs, PRD.md §9 Health].
export const HEALTH_TARGETS: readonly HealthTarget[] = [
  {
    name: "AlarmReactive",
    chainId: lasna.id,
    payer: REACTIVE_SYSTEM_CONTRACT,
    payerLabel: "system contract",
    kind: "protection",
  },
  {
    name: "AlarmExecutor",
    chainId: baseSepolia.id,
    payer: CALLBACK_PROXY[baseSepolia.id],
    payerLabel: "callback proxy",
    kind: "protection",
  },
  { name: "G1Reactive", chainId: lasna.id, payer: REACTIVE_SYSTEM_CONTRACT, payerLabel: "system contract", kind: "gate" },
  {
    name: "G1Receiver",
    chainId: baseSepolia.id,
    payer: CALLBACK_PROXY[baseSepolia.id],
    payerLabel: "callback proxy",
    kind: "gate",
  },
];
