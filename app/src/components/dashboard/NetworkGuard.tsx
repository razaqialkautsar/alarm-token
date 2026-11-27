"use client";

import { useConnection, useSwitchChain } from "wagmi";
import { APP_CHAINS, baseSepolia } from "@/config/chains";

/**
 * Blocks the app on a chain outside `APP_CHAINS` (testnets only, CLAUDE.md §6.4). Wagmi leaves `chain` undefined when
 * the wallet is on a chain the config does not know, which includes every mainnet.
 * Screens that send transactions must also disable their buttons while `chain` is undefined.
 */
export function NetworkGuard() {
  const { isConnected, chain, chainId } = useConnection();
  const { switchChain, isPending, error } = useSwitchChain();

  if (!isConnected || chain) return null;

  return (
    <div role="alert" className="border-b border-alarm bg-alarm/10 px-6 py-4 text-sm">
      <p className="font-semibold text-alarm">Wrong network (chain ID {chainId ?? "unknown"}).</p>
      <p className="mt-1 text-paper/80">
        nothief runs on testnets only. Switch your wallet to one of: {APP_CHAINS.map((c) => c.name).join(", ")}.
      </p>
      <button
        type="button"
        disabled={isPending}
        onClick={() => switchChain({ chainId: baseSepolia.id })}
        className="mt-3 rounded-full bg-alarm px-4 py-1.5 font-semibold text-ink disabled:opacity-60"
      >
        {isPending ? "Switching…" : `Switch to ${baseSepolia.name}`}
      </button>
      {error ? <p className="mt-2 text-alarm">{error.message.split("\n")[0]}</p> : null}
    </div>
  );
}
