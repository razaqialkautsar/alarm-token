"use client";

import type { Address } from "viem";
import { formatEther } from "viem";
import { useBalance, useBlockNumber, useReadContracts } from "wagmi";
import { chainById } from "@/config/chains";
import { deployedAddress } from "@/config/deployments";
import { HEALTH_TARGETS, type HealthTarget, payerAbi } from "@/config/health";
import { addressUrl, blockUrl, shortHex } from "@/lib/explorer";
import { SourceLink } from "./SourceLink";

export function HealthPanel() {
  return (
    <div className="grid gap-4 md:grid-cols-2">
      {HEALTH_TARGETS.map((target) => (
        <HealthCard key={`${target.chainId}-${target.name}`} target={target} />
      ))}
    </div>
  );
}

function HealthCard({ target }: { target: HealthTarget }) {
  const address = deployedAddress(target.chainId, target.name);
  const chain = chainById(target.chainId);

  return (
    <article className="rounded-2xl border border-paper/15 p-5">
      <header className="flex flex-wrap items-baseline justify-between gap-2">
        <h3 className="font-display text-lg">{target.name}</h3>
        <span className="text-sm text-paper/60">{chain?.name}</span>
      </header>
      {target.kind === "gate" ? (
        <p className="mt-1 text-xs text-paper/60">Gate experiment. Not part of the protection loop.</p>
      ) : null}
      {address ? (
        <DeployedHealth target={target} address={address} />
      ) : (
        <p className="mt-4 text-sm text-paper/60">Not deployed yet. No data yet.</p>
      )}
    </article>
  );
}

function DeployedHealth({ target, address }: { target: HealthTarget; address: Address }) {
  const chain = chainById(target.chainId);
  const symbol = chain?.nativeCurrency.symbol ?? "";
  const block = useBlockNumber({ chainId: target.chainId });
  const blockNumber = block.data;
  const enabled = blockNumber !== undefined;

  const reads = useReadContracts({
    contracts: [
      { address: target.payer, abi: payerAbi, functionName: "debt", args: [address], chainId: target.chainId },
      { address: target.payer, abi: payerAbi, functionName: "reserves", args: [address], chainId: target.chainId },
    ],
    blockNumber,
    query: { enabled },
  });
  const balance = useBalance({ address, chainId: target.chainId, blockNumber, query: { enabled } });

  const debt = reads.data?.[0];
  const reserves = reads.data?.[1];
  const loading = block.isPending || reads.isPending || balance.isPending;
  const failed = block.isError || reads.isError || debt?.status === "failure";
  const payerUrl = addressUrl(target.chainId, target.payer);

  function refresh() {
    void block.refetch();
    void reads.refetch();
    void balance.refetch();
  }

  return (
    <div className="mt-4 text-sm">
      <p>
        <SourceLink href={addressUrl(target.chainId, address)} mono>
          {shortHex(address)}
        </SourceLink>
      </p>

      <Status loading={loading} failed={failed} debt={debt?.status === "success" ? debt.result : undefined} />

      <dl className="mt-4 grid grid-cols-[auto_1fr] gap-x-4 gap-y-2">
        <dt className="text-paper/60">debt()</dt>
        <dd>
          <Value read={debt} symbol={symbol} href={payerUrl} />
        </dd>
        <dt className="text-paper/60">reserves()</dt>
        <dd>
          <Value read={reserves} symbol={symbol} href={payerUrl} />
        </dd>
        <dt className="text-paper/60">Balance</dt>
        <dd>
          {balance.data ? (
            <SourceLink href={addressUrl(target.chainId, address)} title={`${balance.data.value} wei`}>
              {formatEther(balance.data.value)} {symbol}
            </SourceLink>
          ) : balance.isError ? (
            <span className="text-alarm">Read failed</span>
          ) : (
            <span className="text-paper/60">Reading…</span>
          )}
        </dd>
      </dl>

      <footer className="mt-4 flex flex-wrap items-center justify-between gap-2 text-xs text-paper/60">
        <span>
          debt() and reserves() read on the {target.payerLabel}
          {blockNumber !== undefined ? (
            <>
              {" "}
              at block <SourceLink href={blockUrl(target.chainId, blockNumber)}>{blockNumber.toString()}</SourceLink>
            </>
          ) : null}
        </span>
        <button
          type="button"
          onClick={refresh}
          className="rounded-full border border-paper/30 px-3 py-1 text-paper hover:border-paper"
        >
          Refresh
        </button>
      </footer>
    </div>
  );
}

function Status({ loading, failed, debt }: { loading: boolean; failed: boolean; debt: bigint | undefined }) {
  if (failed) return <p className="mt-3 font-semibold text-alarm">Read failed. Health unknown.</p>;
  if (loading || debt === undefined) return <p className="mt-3 text-paper/60">Reading…</p>;
  if (debt > BigInt(0)) {
    return (
      <p role="alert" className="mt-3 rounded-lg bg-alarm px-3 py-2 font-semibold text-ink">
        In debt: this contract has stopped executing. Call coverDebt() after funding it.
      </p>
    );
  }
  return <p className="mt-3 font-semibold">No debt</p>;
}

type Read = { status: "success"; result: bigint } | { status: "failure"; error: Error } | undefined;

function Value({ read, symbol, href }: { read: Read; symbol: string; href: string | null }) {
  if (!read) return <span className="text-paper/60">Reading…</span>;
  if (read.status === "failure") return <span className="text-alarm">Read failed</span>;
  return (
    <SourceLink href={href} title={`${read.result} wei`}>
      {formatEther(read.result)} {symbol}
    </SourceLink>
  );
}
