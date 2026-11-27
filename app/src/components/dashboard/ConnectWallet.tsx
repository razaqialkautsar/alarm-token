"use client";

import { useConnect, useConnection, useConnectors, useDisconnect } from "wagmi";
import { shortHex } from "@/lib/explorer";

export function ConnectWallet() {
  const { address, chain, isConnected } = useConnection();
  const connectors = useConnectors();
  const { connect, isPending, error } = useConnect();
  const { disconnect } = useDisconnect();

  if (isConnected && address) {
    return (
      <div className="flex items-center gap-3 text-sm">
        <span className="font-mono" title={address}>
          {shortHex(address)}
        </span>
        <span className="text-paper/60">{chain?.name ?? "Unsupported network"}</span>
        <button
          type="button"
          onClick={() => disconnect()}
          className="rounded-full border border-paper/30 px-3 py-1 hover:border-paper"
        >
          Disconnect
        </button>
      </div>
    );
  }

  // Wallets announced through EIP-6963 appear as their own connectors. The generic `injected` one is then a duplicate
  // of one of them, so it is only shown when no wallet announced itself.
  const announced = connectors.filter((connector) => connector.id !== "injected");
  const shown = announced.length > 0 ? announced : connectors;

  return (
    <div className="flex flex-col items-end gap-1 text-sm">
      <div className="flex flex-wrap justify-end gap-2">
        {shown.map((connector) => (
          <button
            key={connector.uid}
            type="button"
            disabled={isPending}
            onClick={() => connect({ connector })}
            className="rounded-full bg-alarm px-4 py-1.5 font-semibold text-ink disabled:opacity-60"
          >
            {isPending ? "Connecting…" : `Connect ${connector.name}`}
          </button>
        ))}
      </div>
      {/* No browser wallet: `connect` fails with a "provider not found" error, shown here. */}
      {error ? <span className="text-alarm">{error.message.split("\n")[0]}</span> : null}
    </div>
  );
}
