"use client";

import { useQuery } from "@tanstack/react-query";
import { usePublicClient } from "wagmi";
import { CALLBACK_PROXY, baseSepolia, chainById, lasna } from "@/config/chains";
import { deployedAddress } from "@/config/deployments";
import { type EvidenceStep, G1_RUN2, GATES_DOC_URL } from "@/config/gateEvidence";
import { type CallbackOutcome, callbackOutcome } from "@/lib/callbackOutcome";
import { blockUrl, shortHex, txUrl, utc } from "@/lib/explorer";
import { SourceLink } from "./SourceLink";

type StepRead = EvidenceStep & {
  success: boolean;
  blockNumber: bigint;
  timestamp: bigint;
  outcome: CallbackOutcome | null;
};

export function G1LoopPanel() {
  const baseClient = usePublicClient({ chainId: baseSepolia.id });
  const lasnaClient = usePublicClient({ chainId: lasna.id });
  const reactive = deployedAddress(lasna.id, "G1Reactive");
  const receiver = deployedAddress(baseSepolia.id, "G1Receiver");

  const query = useQuery({
    queryKey: ["gate-g1-run2"],
    enabled: Boolean(baseClient && lasnaClient),
    // Finished transactions: the receipts never change.
    staleTime: Infinity,
    queryFn: async (): Promise<StepRead[]> =>
      Promise.all(
        G1_RUN2.map(async (step) => {
          const client = step.chainId === lasna.id ? lasnaClient! : baseClient!;
          const receipt = await client.getTransactionReceipt({ hash: step.hash });
          const block = await client.getBlock({ blockNumber: receipt.blockNumber });
          const outcome =
            step.kind === "callback" && reactive && receiver
              ? callbackOutcome(receipt.logs, CALLBACK_PROXY[baseSepolia.id], reactive, receiver)
              : null;
          return {
            ...step,
            success: receipt.status === "success",
            blockNumber: receipt.blockNumber,
            timestamp: block.timestamp,
            outcome,
          };
        }),
      ),
  });

  const origin = query.data?.find((s) => s.kind === "origin");

  return (
    <div className="text-sm">
      <p className="text-paper/80">
        Gate G1, run 2 (26 Nov 2026): one <code>Ping(3)</code> on Base Sepolia, then three callbacks. Each later round
        was started only by the <code>Progress</code> event of the callback before it. A testnet drill played by the
        team. Source: <SourceLink href={GATES_DOC_URL}>docs/gates.md</SourceLink>.
      </p>

      {query.isPending ? <p className="mt-4 text-paper/60">Reading transactions…</p> : null}
      {query.isError ? (
        <p className="mt-4 text-alarm">Read failed: {query.error.message.split("\n")[0]}</p>
      ) : null}

      {query.data ? (
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[720px] border-collapse text-left">
            <thead className="text-xs text-paper/60">
              <tr className="border-b border-paper/15">
                <th className="py-2 pr-4 font-medium">Step</th>
                <th className="py-2 pr-4 font-medium">Chain</th>
                <th className="py-2 pr-4 font-medium">Tx</th>
                <th className="py-2 pr-4 font-medium">Block</th>
                <th className="py-2 pr-4 font-medium">Block time</th>
                <th className="py-2 pr-4 font-medium">After origin (Base to Base)</th>
                <th className="py-2 font-medium">Callback</th>
              </tr>
            </thead>
            <tbody>
              {query.data.map((step) => (
                <tr key={step.hash} className="border-b border-paper/10">
                  <td className="py-2 pr-4">{step.label}</td>
                  <td className="py-2 pr-4 text-paper/80">{chainById(step.chainId)?.name}</td>
                  <td className="py-2 pr-4">
                    <SourceLink href={txUrl(step.chainId, step.hash)} mono>
                      {shortHex(step.hash)}
                    </SourceLink>
                    {step.success ? null : <span className="ml-2 text-alarm">reverted</span>}
                  </td>
                  <td className="py-2 pr-4">
                    <SourceLink href={blockUrl(step.chainId, step.blockNumber)}>{step.blockNumber.toString()}</SourceLink>
                  </td>
                  <td className="py-2 pr-4 font-mono text-xs">{utc(step.timestamp)}</td>
                  <td className="py-2 pr-4">
                    {origin && step.kind === "callback" ? `+${step.timestamp - origin.timestamp} s` : "—"}
                  </td>
                  <td className="py-2">
                    <Outcome outcome={step.outcome} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}

      <ul className="mt-4 list-disc space-y-1 pl-5 text-xs text-paper/60">
        <li>One run (n = 1). This is not a latency report; G5 will report p50, p95 and n.</li>
        <li>
          Delays are measured only between Base Sepolia blocks. Lasna and Base clocks are not aligned to the second (the
          Lasna block of round 3 is stamped before the origin block), so cross-chain differences are not shown.
        </li>
        <li>
          Callback status comes from the callback tx logs: a <code>CallbackFailure</code> event from the callback proxy
          means it failed. <code>getCallbacks()</code> on the system contract is not used: in G1 it returned an empty
          list after a delivered callback.
        </li>
      </ul>
    </div>
  );
}

function Outcome({ outcome }: { outcome: CallbackOutcome | null }) {
  if (outcome === null) return <span className="text-paper/40">—</span>;
  if (outcome === "failed") return <span className="font-semibold text-alarm">Failed (CallbackFailure)</span>;
  if (outcome === "delivered") return <span className="font-semibold">Delivered</span>;
  return <span className="text-paper/60">Unknown</span>;
}
