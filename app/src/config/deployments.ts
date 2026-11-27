import type { Address } from "viem";
import baseSepoliaFile from "../../../deployments/base-sepolia.json";
import ethereumSepoliaFile from "../../../deployments/ethereum-sepolia.json";
import lasnaFile from "../../../deployments/reactive-lasna.json";

// Contract addresses come only from `deployments/<chain>.json` (CLAUDE.md §6.5), written by the deploy scripts on
// `--broadcast`. The app never hard-codes a deployed address.

type DeploymentFile = { chainId: number; contracts: Record<string, { address: string }> };

const FILES: readonly DeploymentFile[] = [baseSepoliaFile, ethereumSepoliaFile, lasnaFile];

/** Address of contract `name` on `chainId`, or `null` when it has not been deployed (no entry in the file). */
export function deployedAddress(chainId: number, name: string): Address | null {
  const file = FILES.find((f) => f.chainId === chainId);
  const address = file?.contracts[name]?.address;
  return address ? (address as Address) : null;
}
