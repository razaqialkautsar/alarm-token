import type { Address, PublicClient } from "viem";

// DVN config read for the registration warning (M10, PRD.md §20.3). Read-only.
// [Fact: LayerZero V2 source, `MessageLibManager.getReceiveLibrary`, `UlnBase.getUlnConfig`,
//  `ReceiveUlnBase._checkVerifiable`, read 27 Nov 2026 from the pinned npm packages in `contracts/`.]
// Not yet proven with a real call on testnet (gate G3): `getUlnConfig` on the returned library is an inference from
// `ReceiveUln302 is ReceiveUlnBase is UlnBase`.

export const endpointReceiveLibraryAbi = [
  {
    type: "function",
    name: "getReceiveLibrary",
    stateMutability: "view",
    inputs: [
      { name: "_receiver", type: "address" },
      { name: "_srcEid", type: "uint32" },
    ],
    outputs: [
      { name: "lib", type: "address" },
      { name: "isDefault", type: "bool" },
    ],
  },
] as const;

export const ulnConfigAbi = [
  {
    type: "function",
    name: "getUlnConfig",
    stateMutability: "view",
    inputs: [
      { name: "_oapp", type: "address" },
      { name: "_remoteEid", type: "uint32" },
    ],
    outputs: [
      {
        name: "rtnConfig",
        type: "tuple",
        components: [
          { name: "confirmations", type: "uint64" },
          { name: "requiredDVNCount", type: "uint8" },
          { name: "optionalDVNCount", type: "uint8" },
          { name: "optionalDVNThreshold", type: "uint8" },
          { name: "requiredDVNs", type: "address[]" },
          { name: "optionalDVNs", type: "address[]" },
        ],
      },
    ],
  },
] as const;

/** Effective receive config. `getUlnConfig` already merges defaults and resolves "NONE" (255) to a count of 0. */
export type UlnConfig = {
  confirmations: bigint;
  requiredDVNCount: number;
  optionalDVNCount: number;
  optionalDVNThreshold: number;
  requiredDVNs: readonly Address[];
  optionalDVNs: readonly Address[];
};

export type DvnConfigRead = { library: Address; libraryIsDefault: boolean; config: UlnConfig };

/** Reads the receive library and its effective DVN config for messages from `srcEid` to `oapp`. */
export async function readDvnConfig(
  client: PublicClient,
  endpoint: Address,
  oapp: Address,
  srcEid: number,
): Promise<DvnConfigRead> {
  const [library, libraryIsDefault] = await client.readContract({
    address: endpoint,
    abi: endpointReceiveLibraryAbi,
    functionName: "getReceiveLibrary",
    args: [oapp, srcEid],
  });
  const config = await client.readContract({
    address: library,
    abi: ulnConfigAbi,
    functionName: "getUlnConfig",
    args: [oapp, srcEid],
  });
  return { library, libraryIsDefault, config };
}

/**
 * Smallest number of distinct DVNs whose signatures can verify a message under `config`.
 * All required DVNs must sign. When optional DVNs exist, `optionalDVNThreshold` of them must sign too, and a DVN that
 * is in both lists counts for both (`ReceiveUlnBase._checkVerifiable`). So overlapping DVNs lower the minimum.
 * 0 means no DVN is configured: `_checkVerifiable` returns false and no message can be verified.
 */
export function minDistinctDvns(config: UlnConfig): number {
  const required = new Set(config.requiredDVNs.slice(0, config.requiredDVNCount).map((a) => a.toLowerCase()));
  if (config.optionalDVNCount === 0) return required.size;
  const optional = config.optionalDVNs.slice(0, config.optionalDVNCount).map((a) => a.toLowerCase());
  const overlap = optional.filter((a) => required.has(a)).length;
  return required.size + Math.max(0, config.optionalDVNThreshold - overlap);
}

/**
 * M10 warning: one DVN alone can verify messages (the 1-of-1 setup behind the KelpDAO incident, PRD.md §2.3).
 * [Opinion: the team still has to confirm that "1-of-N optional with threshold 1" also counts as 1-of-1.]
 */
export function isSingleDvn(config: UlnConfig): boolean {
  return minDistinctDvns(config) === 1;
}
