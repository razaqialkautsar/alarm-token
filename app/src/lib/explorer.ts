import type { Address, Hash } from "viem";
import { chainById } from "@/config/chains";

// Every displayed number links to its source (CLAUDE.md §6.4). Path formats checked on 27 Nov 2026: Reactscan
// answered /tx/, /address/ and /block/ with the matching page; Basescan and Etherscan use the same paths.

function base(chainId: number): string | null {
  return chainById(chainId)?.blockExplorers?.default.url ?? null;
}

export function txUrl(chainId: number, hash: Hash): string | null {
  const root = base(chainId);
  return root ? `${root}/tx/${hash}` : null;
}

export function addressUrl(chainId: number, address: Address): string | null {
  const root = base(chainId);
  return root ? `${root}/address/${address}` : null;
}

export function blockUrl(chainId: number, block: bigint): string | null {
  const root = base(chainId);
  return root ? `${root}/block/${block}` : null;
}

export function shortHex(value: string, chars = 4): string {
  return value.length <= 2 + chars * 2 ? value : `${value.slice(0, 2 + chars)}…${value.slice(-chars)}`;
}

/** Block timestamp as ISO UTC without milliseconds, e.g. `2026-11-26 09:00:14 UTC`. */
export function utc(timestamp: bigint): string {
  return `${new Date(Number(timestamp) * 1000).toISOString().replace("T", " ").slice(0, 19)} UTC`;
}
